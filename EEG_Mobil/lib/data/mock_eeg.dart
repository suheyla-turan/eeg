import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/eeg_sample.dart';
import 'sensors.dart';

/// Python API `connection` alanıyla uyumlu durumlar.
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  deviceFound,
  deviceNotWorn,
}

enum ContactQuality { good, fair, poor, none }

class EmotionScore {
  final String key;
  final String label;
  final int score;
  final Color color;

  const EmotionScore({
    required this.key,
    required this.label,
    required this.score,
    required this.color,
  });
}

class LiveEegState {
  final ConnectionStatus connection;
  final bool collecting;
  final int batteryPercent;
  final int sensorCount;
  final Map<String, ContactQuality> contactQuality;
  final Map<String, int> rawContactQuality;
  final Map<String, double> bandPower;
  final Map<String, double> relativeBandPower;
  final Map<String, Map<String, double>> regionBandPower;
  final EegSample eeg;
  final double signal;
  final int overallQuality;
  final bool eegSubscribed;
  final bool eegStreamActive;
  final bool hasSpectral;
  final double? updatedAt;
  final String? error;

  const LiveEegState({
    required this.connection,
    this.collecting = false,
    required this.batteryPercent,
    required this.sensorCount,
    required this.contactQuality,
    required this.rawContactQuality,
    required this.bandPower,
    this.relativeBandPower = const {},
    this.regionBandPower = const {},
    required this.eeg,
    this.signal = 0,
    this.overallQuality = 0,
    this.eegSubscribed = false,
    this.eegStreamActive = false,
    this.hasSpectral = false,
    this.updatedAt,
    this.error,
  });

  /// Deney: cihaz bağlı + EEG stream / spektral veri akıyor olmalı.
  /// Yalnızca DEV (contact quality) ile deney başlatılmaz.
  bool get canStartExperiment =>
      connection == ConnectionStatus.connected &&
      (eegStreamActive || hasSpectral);

  String get connectionLabelTr => switch (connection) {
        ConnectionStatus.connected => 'Bağlı',
        ConnectionStatus.connecting => 'Bağlanıyor',
        ConnectionStatus.disconnected => 'Bağlantı Yok',
        ConnectionStatus.deviceFound => 'Cihaz Bulundu',
        ConnectionStatus.deviceNotWorn => 'Cihaz Takılı Değil',
      };

  factory LiveEegState.disconnected({String? error, bool collecting = false}) {
    return LiveEegState(
      connection: ConnectionStatus.disconnected,
      collecting: collecting,
      batteryPercent: 0,
      sensorCount: 14,
      contactQuality: {for (final id in sensorIds) id: ContactQuality.none},
      rawContactQuality: {for (final id in sensorIds) id: 0},
      bandPower: const {},
      relativeBandPower: const {},
      regionBandPower: const {},
      eeg: EegSample.empty(),
      error: error,
    );
  }

  /// Cihaz / Python API olmadan UI ve deney akışını test etmek için.
  factory LiveEegState.demo({
    required double phase,
    bool collecting = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final quality = <String, int>{};
    final contact = <String, ContactQuality>{};
    for (var i = 0; i < sensorIds.length; i++) {
      final id = sensorIds[i];
      final q = 3 + (math.sin(phase + i * 0.4) > 0.3 ? 1 : 0);
      quality[id] = q.clamp(2, 4);
      contact[id] = contactQualityFromEmotiv(quality[id]!);
    }

    // Demo spektral bantlar (sinüs ile salınır) — yalnızca UI test
    final bandPower = <String, double>{
      'delta': 0.15 + 0.05 * math.sin(phase * 0.3),
      'theta': 0.20 + 0.06 * math.sin(phase * 0.5 + 1),
      'alpha': 0.28 + 0.08 * math.sin(phase * 0.4 + 2),
      'beta': 0.25 + 0.07 * math.sin(phase * 0.7 + 0.5),
      'gamma': 0.12 + 0.04 * math.sin(phase * 1.1),
    };
    final total = bandPower.values.reduce((a, b) => a + b);
    final relativeBandPower = {
      for (final e in bandPower.entries) e.key: e.value / total,
    };

    double ch(int i, double amp) =>
        amp * math.sin(phase * (1.0 + i * 0.07)) +
        amp * 0.35 * math.sin(phase * 2.3 + i);

    final eeg = EegSample(
      timestamp: now,
      af3: ch(0, 42),
      f7: ch(1, 38),
      f3: ch(2, 45),
      fc5: ch(3, 36),
      t7: ch(4, 33),
      p7: ch(5, 31),
      o1: ch(6, 40),
      o2: ch(7, 41),
      p8: ch(8, 32),
      t8: ch(9, 34),
      fc6: ch(10, 37),
      f4: ch(11, 44),
      f8: ch(12, 39),
      af4: ch(13, 43),
    );

    return LiveEegState(
      connection: ConnectionStatus.connected,
      collecting: collecting,
      batteryPercent: 87,
      sensorCount: 14,
      contactQuality: contact,
      rawContactQuality: quality,
      bandPower: bandPower,
      relativeBandPower: relativeBandPower,
      regionBandPower: {
        'attention_frontal': Map<String, double>.from(bandPower),
        'frontal': Map<String, double>.from(bandPower),
      },
      eeg: eeg,
      signal: 0.82 + 0.1 * math.sin(phase),
      overallQuality: 85,
      eegSubscribed: true,
      eegStreamActive: true,
      hasSpectral: true,
      updatedAt: now,
    );
  }

  factory LiveEegState.fromJson(Map<String, dynamic> json) {
    final connection = parseConnectionStatus(json['connection'] as String?);

    final rawQuality =
        (json['contact_quality'] as Map<String, dynamic>?) ?? {};
    final contactQuality = <String, ContactQuality>{};
    final rawContactQuality = <String, int>{};

    for (final id in sensorIds) {
      final raw = (rawQuality[id] as num?)?.toInt() ?? 0;
      rawContactQuality[id] = raw;
      contactQuality[id] = contactQualityFromEmotiv(raw);
    }

    // API spektral band_power — yoksa boş. Contact quality'den EEG ÜRETİLMEZ.
    Map<String, double> readBands(dynamic raw) {
      final out = <String, double>{};
      if (raw is! Map) return out;
      for (final key in ['delta', 'theta', 'alpha', 'beta', 'gamma']) {
        final v = raw[key];
        if (v is num) out[key] = v.toDouble();
      }
      return out;
    }

    final bandPower = readBands(json['band_power']);
    final relativeBandPower = readBands(json['relative_band_power']);

    final regionBandPower = <String, Map<String, double>>{};
    final regionsRaw = json['region_band_power'];
    if (regionsRaw is Map) {
      for (final entry in regionsRaw.entries) {
        regionBandPower['${entry.key}'] = readBands(entry.value);
      }
    }

    final eegJson = json['eeg'] as Map<String, dynamic>?;
    final eeg = EegSample.fromJson(eegJson);
    // EEG yoksa boş kalır — analiz katmanı "veri yetersiz" döner.
    // Contact quality yalnızca UI temas göstergesi içindir.

    return LiveEegState(
      connection: connection,
      collecting: json['collecting'] as bool? ?? false,
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 0,
      sensorCount: (json['sensor_count'] as num?)?.toInt() ?? 14,
      contactQuality: contactQuality,
      rawContactQuality: rawContactQuality,
      bandPower: bandPower,
      relativeBandPower: relativeBandPower,
      regionBandPower: regionBandPower,
      eeg: eeg,
      signal: (json['signal'] as num?)?.toDouble() ?? 0,
      overallQuality: (json['overall_quality'] as num?)?.toInt() ?? 0,
      eegSubscribed: json['eeg_subscribed'] as bool? ?? false,
      eegStreamActive: json['eeg_stream_active'] as bool? ?? false,
      hasSpectral: json['has_spectral'] as bool? ??
          bandPower.values.any((v) => v.abs() > 1e-12),
      updatedAt: (json['updated_at'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }
}

ConnectionStatus parseConnectionStatus(String? value) {
  return switch (value) {
    'connected' => ConnectionStatus.connected,
    'connecting' => ConnectionStatus.connecting,
    'device_found' => ConnectionStatus.deviceFound,
    'device_not_worn' => ConnectionStatus.deviceNotWorn,
    _ => ConnectionStatus.disconnected,
  };
}

ContactQuality contactQualityFromEmotiv(int value) {
  // Emotiv: 0 yok, 1 çok zayıf, 2 zayıf, 3 orta, 4 iyi
  if (value >= 4) return ContactQuality.good;
  if (value == 3) return ContactQuality.fair;
  if (value >= 1) return ContactQuality.poor;
  return ContactQuality.none;
}

const List<EmotionScore> emotions = [
  EmotionScore(key: 'happy', label: 'Mutlu', score: 0, color: Color(0xFFE8A838)),
  EmotionScore(key: 'sad', label: 'Üzgün', score: 0, color: Color(0xFF5B7C99)),
  EmotionScore(key: 'angry', label: 'Sinirli', score: 0, color: Color(0xFFC44B4B)),
  EmotionScore(key: 'calm', label: 'Sakin', score: 0, color: Color(0xFF1FA8A0)),
  EmotionScore(key: 'stressed', label: 'Stresli', score: 0, color: Color(0xFFD4783A)),
  EmotionScore(key: 'focused', label: 'Odaklı', score: 0, color: Color(0xFF0D7A8C)),
];
