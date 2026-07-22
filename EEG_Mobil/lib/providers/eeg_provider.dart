import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../data/mock_eeg.dart';
import '../data/sensors.dart';
import '../models/eeg_sample.dart';
import '../services/eeg_service.dart';

/// EEG bağlantısı, WebSocket akışı ve grafik geçmişini yönetir.
class EegProvider extends ChangeNotifier {
  EegProvider({required EegService eegService}) : _service = eegService {
    _subscription = _service.liveStream.listen(_onLive);
    unawaited(_service.connect());
  }

  final EegService _service;
  StreamSubscription<LiveEegState>? _subscription;

  static const int maxHistory = 200;

  LiveEegState live = LiveEegState.disconnected();
  final ListQueue<EegSample> history = ListQueue<EegSample>(maxHistory);

  String? selectedChannel;
  bool busy = false;
  bool _autoStreamStarted = false;
  ConnectionStatus? _lastConnection;

  EegService get service => _service;
  ConnectionStatus get connection => live.connection;
  bool get isDemoMode => _service.isDemoMode;
  String get connectionLabel => isDemoMode
      ? '${live.connectionLabelTr} (Demo)'
      : live.connectionLabelTr;
  bool get isConnected => live.connection == ConnectionStatus.connected;
  bool get canStartExperiment => live.canStartExperiment;
  bool get collecting => live.collecting;
  EegSample get latestSample => live.eeg;
  List<String> get channels => sensorIds;

  void _onLive(LiveEegState state) {
    final prev = live.connection;
    live = state;

    final flowing = state.connection == ConnectionStatus.connected ||
        state.connection == ConnectionStatus.deviceNotWorn ||
        state.connection == ConnectionStatus.deviceFound;

    if (flowing && state.eeg.hasSignal) {
      history.addLast(state.eeg);
      while (history.length > maxHistory) {
        history.removeFirst();
      }
    }

    if (state.connection == ConnectionStatus.connected &&
        _lastConnection != ConnectionStatus.connected &&
        !_autoStreamStarted) {
      _autoStreamStarted = true;
      unawaited(_autoStartCollection());
    }

    if (state.connection != ConnectionStatus.connected) {
      if (_lastConnection == ConnectionStatus.connected) {
        _autoStreamStarted = false;
        AppLogger.instance.eeg(
          'Bağlantı koptu: ${state.connectionLabelTr}',
          level: LogLevel.warning,
        );
      }
    } else if (prev != ConnectionStatus.connected) {
      AppLogger.instance.eeg('Bağlantı kuruldu');
    }

    _lastConnection = state.connection;
    notifyListeners();
  }

  Future<void> _autoStartCollection() async {
    if (live.collecting) return;
    try {
      await _service.startCollection();
      AppLogger.instance.eeg('Veri toplama otomatik başlatıldı');
    } catch (e) {
      AppLogger.instance.eeg(
        'Auto startCollection hatası',
        level: LogLevel.error,
        error: e,
      );
    }
  }

  Future<void> reconnect() async {
    AppLogger.instance.eeg('Yeniden bağlanılıyor');
    await _service.disconnect();
    await _service.connect();
  }

  void selectChannel(String? channel) {
    if (channel != null && !sensorIds.contains(channel)) return;
    selectedChannel = channel;
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  Future<void> toggleCollection() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      if (live.collecting) {
        await _service.stopCollection();
        AppLogger.instance.eeg('Toplama durduruldu');
      } else {
        await _service.startCollection();
        AppLogger.instance.eeg('Toplama başlatıldı');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  List<double> seriesFor(String channel) {
    return history.map((s) => s[channel]).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
