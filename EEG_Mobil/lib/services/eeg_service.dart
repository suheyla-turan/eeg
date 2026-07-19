import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/app_logger.dart';
import '../data/mock_eeg.dart';
import 'eeg_api_service.dart';

/// Python EEG API ile WebSocket üzerinden sürekli canlı veri alır.
///
/// Endpoint: `ws://host:8000/ws/live`
///
/// Host keşfi ve REST komutları [EegApiService] üzerinden yapılır.
///
/// [demoMode] açıkken gerçek cihaz / Python API gerekmez; sahte sinyal üretilir.
class EegService {
  EegService({
    required EegApiService api,
    bool ownsApi = false,
    bool demoMode = false,
  })  : _api = api,
        _ownsApi = ownsApi,
        _demoMode = demoMode;

  final EegApiService _api;
  final bool _ownsApi;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _demoTimer;
  bool _disposed = false;
  bool _connecting = false;
  int _reconnectAttempt = 0;
  bool _demoMode;
  bool _demoCollecting = false;
  double _demoPhase = 0;

  final _liveController = StreamController<LiveEegState>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  LiveEegState _latest = LiveEegState.disconnected();
  bool _streaming = false;

  Stream<LiveEegState> get liveStream => _liveController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  LiveEegState get latest => _latest;
  bool get isStreaming => _streaming;
  bool get isDemoMode => _demoMode;
  EegApiService get api => _api;

  /// Demo bayrağını senkron ayarlar (connect öncesi Settings için).
  void prepareDemoMode(bool enabled) {
    _demoMode = enabled;
  }

  /// Demo modunu aç/kapat ve akışı yeniden başlat.
  Future<void> setDemoMode(bool enabled) async {
    if (_demoMode == enabled && (_streaming || _connecting)) return;
    await disconnect();
    _demoMode = enabled;
    _demoCollecting = false;
    _demoPhase = 0;
    _reconnectAttempt = 0;
    if (!_disposed) {
      await connect();
    }
  }

  /// mDNS / yedek host ile WebSocket akışını başlatır (veya demo ticker).
  Future<void> connect() async {
    if (_disposed || _connecting || _streaming) return;
    _connecting = true;
    _emitStatus(ConnectionStatus.connecting);

    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_disposed) return;
      _streaming = true;
      _connecting = false;
      _demoCollecting = true;
      _startDemoTicker();
      _emit(_buildDemoState());
      AppLogger.instance.eeg('Demo modu — sahte EEG akışı başladı');
      return;
    }

    try {
      // Host çözümlemesi için kısa REST denemesi
      try {
        final warm = await _api.fetchLive();
        _emit(warm);
      } catch (_) {
        // REST başarısız olsa bile WS aday hostlarla denenecek
      }

      final hosts = await _api.candidateHosts();
      Object? lastError;

      for (final host in hosts) {
        if (_disposed) return;
        try {
          await _openSocket(host);
          _reconnectAttempt = 0;
          _connecting = false;
          return;
        } catch (e) {
          lastError = e;
          AppLogger.instance.eeg(
            'WS başarısız ($host)',
            level: LogLevel.warning,
            error: e,
          );
        }
      }

      _connecting = false;
      _emit(
        LiveEegState.disconnected(
          error: lastError?.toString() ??
              'WebSocket bağlantısı kurulamadı (${EegApiConfig.displayUrl})',
        ),
      );
      AppLogger.instance.eeg(
        'WebSocket bağlantısı kurulamadı',
        level: LogLevel.error,
        error: lastError,
      );
      _scheduleReconnect();
    } catch (e) {
      _connecting = false;
      _emit(LiveEegState.disconnected(error: e.toString()));
      AppLogger.instance.eeg(
        'Bağlantı hatası',
        level: LogLevel.error,
        error: e,
      );
      _scheduleReconnect();
    }
  }

  void _startDemoTicker() {
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || !_demoMode || !_streaming) return;
      _demoPhase += 0.18;
      _emit(_buildDemoState());
    });
  }

  LiveEegState _buildDemoState() {
    return LiveEegState.demo(
      phase: _demoPhase,
      collecting: _demoCollecting,
    );
  }

  Future<void> _openSocket(String host) async {
    final uri = Uri.parse('ws://$host:${EegApiConfig.port}/ws/live');
    AppLogger.instance.eeg('WS bağlanıyor: $uri');

    final channel = WebSocketChannel.connect(uri);
    // İlk frame için kısa bekleme — bağlantı hatasını yakala
    await channel.ready.timeout(const Duration(seconds: 4));

    await _subscription?.cancel();
    await _channel?.sink.close();

    _channel = channel;
    _streaming = true;
    EegApiConfig.host = host;
    AppLogger.instance.eeg('WS bağlandı: $host');

    _subscription = channel.stream.listen(
      (event) {
        try {
          final text = event is String ? event : utf8.decode(event as List<int>);
          final json = jsonDecode(text) as Map<String, dynamic>;
          final state = LiveEegState.fromJson(json);
          _emit(state);
        } catch (e) {
          AppLogger.instance.eeg(
            'WS parse hatası',
            level: LogLevel.warning,
            error: e,
          );
        }
      },
      onError: (Object e) {
        AppLogger.instance.eeg('WS hata', level: LogLevel.error, error: e);
        _onSocketClosed(e.toString());
      },
      onDone: () => _onSocketClosed('WebSocket kapandı'),
      cancelOnError: true,
    );
  }

  void _onSocketClosed(String reason) {
    _streaming = false;
    _subscription = null;
    _channel = null;
    if (_disposed) return;
    if (_demoMode) return;
    _emit(LiveEegState.disconnected(error: reason));
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _demoMode) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 + _reconnectAttempt).clamp(2, 10));
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && !_streaming && !_demoMode) {
        connect();
      }
    });
  }

  Future<void> startCollection() async {
    if (_demoMode) {
      _demoCollecting = true;
      _emit(_buildDemoState());
      AppLogger.instance.eeg('Demo: toplama açıldı');
      return;
    }
    await _api.startCollection();
  }

  Future<void> stopCollection() async {
    if (_demoMode) {
      _demoCollecting = false;
      _emit(_buildDemoState());
      AppLogger.instance.eeg('Demo: toplama kapatıldı');
      return;
    }
    await _api.stopCollection();
  }

  Future<LiveEegState> fetchLive() async {
    if (_demoMode) {
      if (_streaming) return _latest;
      return _buildDemoState();
    }
    return _api.fetchLive();
  }

  void _emit(LiveEegState state) {
    _latest = state;
    if (!_liveController.isClosed) _liveController.add(state);
    _emitStatus(state.connection);
  }

  void _emitStatus(ConnectionStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _streaming = false;
    _connecting = false;
    if (_demoMode) {
      _emit(LiveEegState.disconnected());
    }
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _liveController.close();
    _statusController.close();
    if (_ownsApi) _api.dispose();
  }
}
