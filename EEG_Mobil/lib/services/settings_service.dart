import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı uygulama ayarları (tema, API host override).
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyThemeMode = 'theme_mode';
  static const _keyApiHost = 'api_host_override';
  static const _keyWsPort = 'ws_port';
  static const _keyDemoMode = 'demo_mode';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  ThemeMode get themeMode {
    final raw = _prefs.getString(_keyThemeMode);
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_keyThemeMode, value);
  }

  /// Boş = otomatik mDNS keşif.
  String? get apiHostOverride {
    final v = _prefs.getString(_keyApiHost);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<void> setApiHostOverride(String? host) async {
    if (host == null || host.trim().isEmpty) {
      await _prefs.remove(_keyApiHost);
    } else {
      await _prefs.setString(_keyApiHost, host.trim());
    }
  }

  int get wsPort => _prefs.getInt(_keyWsPort) ?? 8000;

  Future<void> setWsPort(int port) async {
    await _prefs.setInt(_keyWsPort, port.clamp(1, 65535));
  }

  /// Cihaz olmadan sahte EEG ile uygulama testi.
  bool get demoMode => _prefs.getBool(_keyDemoMode) ?? false;

  Future<void> setDemoMode(bool enabled) async {
    await _prefs.setBool(_keyDemoMode, enabled);
  }
}
