import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_logger.dart';
import '../data/mock_eeg.dart';
import '../services/eeg_api_service.dart';
import '../services/eeg_service.dart';
import '../services/settings_service.dart';

/// Ayarlar + bağlantı durumu (Settings ekranı için).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required SettingsService settingsService,
    required EegService eegService,
    required bool firebaseReady,
  })  : _settings = settingsService,
        _eeg = eegService,
        _firebaseReady = firebaseReady {
    _themeMode = _settings.themeMode;
    _apiHostOverride = _settings.apiHostOverride;
    _wsPort = _settings.wsPort;
    _demoMode = _settings.demoMode;
    // EegProvider.connect() öncesi bayrak hazır olmalı
    _eeg.prepareDemoMode(_demoMode);
    _applyApiConfig();
    _liveSub = _eeg.liveStream.listen((state) {
      _live = state;
      notifyListeners();
    });
    _live = _eeg.latest;
    _loadPackageInfo();
  }

  final SettingsService _settings;
  final EegService _eeg;
  final bool _firebaseReady;

  StreamSubscription<LiveEegState>? _liveSub;
  ThemeMode _themeMode = ThemeMode.system;
  String? _apiHostOverride;
  int _wsPort = 8000;
  bool _demoMode = false;
  LiveEegState _live = LiveEegState.disconnected();
  PackageInfo? _packageInfo;

  ThemeMode get themeMode => _themeMode;
  String? get apiHostOverride => _apiHostOverride;
  int get wsPort => _wsPort;
  bool get demoMode => _demoMode;
  LiveEegState get live => _live;
  bool get firebaseReady => _firebaseReady;
  PackageInfo? get packageInfo => _packageInfo;

  String get apiDisplayHost => _apiHostOverride ?? EegApiConfig.host;

  String get apiDisplayUrl =>
      'http://${_apiHostOverride ?? EegApiConfig.mdnsHost}:$_wsPort';

  String get eegConnectionLabel => _demoMode
      ? '${_live.connectionLabelTr} (Demo)'
      : _live.connectionLabelTr;

  String get firebaseStatusLabel =>
      _firebaseReady ? 'Bağlı (Core · Firestore · Storage)' : 'Başlatılamadı';

  String get versionLabel {
    final info = _packageInfo;
    if (info == null) return '…';
    return '${info.version} (${info.buildNumber})';
  }

  Future<void> _loadPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      notifyListeners();
    } catch (e) {
      AppLogger.instance.error('PackageInfo okunamadı', error: e);
    }
  }

  void _applyApiConfig() {
    EegApiConfig.port = _wsPort;
    EegApiConfig.hostOverride = _apiHostOverride;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settings.setThemeMode(mode);
    AppLogger.instance.experiment('Tema: $mode');
    notifyListeners();
  }

  Future<void> setApiHostOverride(String? host) async {
    _apiHostOverride =
        (host == null || host.trim().isEmpty) ? null : host.trim();
    await _settings.setApiHostOverride(_apiHostOverride);
    _applyApiConfig();
    AppLogger.instance.python(
      'API host override: ${_apiHostOverride ?? "(otomatik)"}',
    );
    notifyListeners();
  }

  Future<void> setWsPort(int port) async {
    _wsPort = port.clamp(1, 65535);
    await _settings.setWsPort(_wsPort);
    _applyApiConfig();
    AppLogger.instance.python('WebSocket port: $_wsPort');
    notifyListeners();
  }

  Future<void> setDemoMode(bool enabled) async {
    _demoMode = enabled;
    await _settings.setDemoMode(enabled);
    AppLogger.instance.eeg(
      enabled
          ? 'Demo modu açıldı — cihaz gerekmez'
          : 'Demo modu kapatıldı — gerçek API',
    );
    await _eeg.setDemoMode(enabled);
    notifyListeners();
  }

  Future<void> reconnectEeg() async {
    AppLogger.instance.eeg('Yeniden bağlanılıyor…');
    await _eeg.disconnect();
    await _eeg.connect();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
