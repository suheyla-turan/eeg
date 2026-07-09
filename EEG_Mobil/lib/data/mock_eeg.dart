import 'package:flutter/material.dart';
import 'sensors.dart';

enum ConnectionStatus { connected, connecting, disconnected }

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
  final int batteryPercent;
  final int sensorCount;
  final Map<String, ContactQuality> contactQuality;
  final Map<String, int> rawContactQuality;
  final Map<String, double> bandPower;
  final double signal;
  final int overallQuality;
  final double? updatedAt;
  final String? error;

  const LiveEegState({
    required this.connection,
    required this.batteryPercent,
    required this.sensorCount,
    required this.contactQuality,
    required this.rawContactQuality,
    required this.bandPower,
    this.signal = 0,
    this.overallQuality = 0,
    this.updatedAt,
    this.error,
  });

  factory LiveEegState.disconnected({String? error}) {
    return LiveEegState(
      connection: ConnectionStatus.disconnected,
      batteryPercent: 0,
      sensorCount: 14,
      contactQuality: {for (final id in sensorIds) id: ContactQuality.none},
      rawContactQuality: {for (final id in sensorIds) id: 0},
      bandPower: {for (final id in sensorIds) id: 0},
      error: error,
    );
  }

  factory LiveEegState.fromJson(Map<String, dynamic> json) {
    final connection = switch (json['connection'] as String? ?? 'disconnected') {
      'connected' => ConnectionStatus.connected,
      'connecting' => ConnectionStatus.connecting,
      _ => ConnectionStatus.disconnected,
    };

    final rawQuality =
        (json['contact_quality'] as Map<String, dynamic>?) ?? {};
    final contactQuality = <String, ContactQuality>{};
    final rawContactQuality = <String, int>{};
    final bandPower = <String, double>{};

    for (final id in sensorIds) {
      final raw = (rawQuality[id] as num?)?.toInt() ?? 0;
      rawContactQuality[id] = raw;
      contactQuality[id] = contactQualityFromEmotiv(raw);
      bandPower[id] = raw.clamp(0, 4) / 4.0;
    }

    return LiveEegState(
      connection: connection,
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 0,
      sensorCount: (json['sensor_count'] as num?)?.toInt() ?? 14,
      contactQuality: contactQuality,
      rawContactQuality: rawContactQuality,
      bandPower: bandPower,
      signal: (json['signal'] as num?)?.toDouble() ?? 0,
      overallQuality: (json['overall_quality'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }
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
