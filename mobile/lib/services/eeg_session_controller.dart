import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';

enum ServerConnectionState { disconnected, connecting, connected, error }

class EegSessionController extends ChangeNotifier {
  EegSessionController({String host = AppConfig.defaultHost}) : _host = host;

  String _host;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  ServerConnectionState connectionState = ServerConnectionState.disconnected;
  AppSnapshot snapshot = AppSnapshot.empty();
  String? errorMessage;
  final List<double> _recentSamples = [];

  String get host => _host;
  String get baseUrl => AppConfig.buildBaseUrl(_host);
  List<double> get recentSamples => List.unmodifiable(_recentSamples);

  void updateHost(String host) {
    _host = host.trim().isEmpty ? AppConfig.defaultHost : host.trim();
  }

  Future<void> connect() async {
    await disconnect();
    connectionState = ServerConnectionState.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.buildWsUrl(_host)));
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
      connectionState = ServerConnectionState.connected;
      notifyListeners();
    } catch (error) {
      _handleConnectionError('Bağlantı kurulamadı: $error');
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    connectionState = ServerConnectionState.disconnected;
    notifyListeners();
  }

  void _onMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final type = decoded['type'] as String? ?? '';

      if (type == 'snapshot') {
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        _applySnapshot(AppSnapshot.fromJson(data));
        return;
      }

      if (type == 'device_status') {
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        snapshot = AppSnapshot(
          device: DeviceStatus.fromJson(data),
          latestEeg: snapshot.latestEeg,
          emotions: snapshot.emotions,
          updatedAt: decoded['updated_at'] as String?,
        );
        notifyListeners();
        return;
      }

      if (type == 'eeg_update') {
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        final eeg = EegData.fromJson(data);
        _appendSamples(eeg.channels);
        snapshot = AppSnapshot(
          device: snapshot.device,
          latestEeg: eeg,
          emotions: snapshot.emotions,
          updatedAt: decoded['updated_at'] as String?,
        );
        notifyListeners();
      }
    } catch (error) {
      errorMessage = 'Veri çözümlenemedi: $error';
      notifyListeners();
    }
  }

  void _applySnapshot(AppSnapshot incoming) {
    snapshot = incoming;
    if (incoming.latestEeg != null) {
      _appendSamples(incoming.latestEeg!.channels);
    }
    notifyListeners();
  }

  void _appendSamples(List<double> channels) {
    if (channels.isEmpty) {
      return;
    }

    _recentSamples.addAll(channels);
    const maxSamples = 120;
    if (_recentSamples.length > maxSamples) {
      _recentSamples.removeRange(0, _recentSamples.length - maxSamples);
    }
  }

  void _onError(Object error) {
    _handleConnectionError('Bağlantı hatası: $error');
  }

  void _onDone() {
    connectionState = ServerConnectionState.disconnected;
    errorMessage = 'Sunucu bağlantısı kapandı';
    notifyListeners();
    _scheduleReconnect();
  }

  void _handleConnectionError(String message) {
    connectionState = ServerConnectionState.error;
    errorMessage = message;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer ??= Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      connect();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
