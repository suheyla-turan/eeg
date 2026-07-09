class DeviceStatus {
  const DeviceStatus({
    required this.connected,
    this.headsetId,
    this.sessionId,
    this.message,
  });

  final bool connected;
  final String? headsetId;
  final String? sessionId;
  final String? message;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      connected: json['connected'] as bool? ?? false,
      headsetId: json['headset_id'] as String?,
      sessionId: json['session_id'] as String?,
      message: json['message'] as String?,
    );
  }
}

class EegData {
  const EegData({
    required this.channels,
    required this.timestamp,
    this.channelCount = 0,
  });

  final List<double> channels;
  final String? timestamp;
  final int channelCount;

  factory EegData.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'] as List<dynamic>? ?? [];
    final channels = rawChannels
        .map((value) => (value as num).toDouble())
        .toList(growable: false);

    return EegData(
      channels: channels,
      timestamp: json['timestamp'] as String?,
      channelCount: json['channel_count'] as int? ?? channels.length,
    );
  }
}

class EmotionScore {
  const EmotionScore({
    required this.key,
    required this.label,
    this.score,
    required this.status,
  });

  final String key;
  final String label;
  final double? score;
  final String status;

  bool get isPending => status == 'pending_ai';

  factory EmotionScore.fromJson(String key, Map<String, dynamic> json) {
    final rawScore = json['score'];
    return EmotionScore(
      key: key,
      label: json['label'] as String? ?? key,
      score: rawScore == null ? null : (rawScore as num).toDouble(),
      status: json['status'] as String? ?? 'pending_ai',
    );
  }
}

class AppSnapshot {
  const AppSnapshot({
    required this.device,
    this.latestEeg,
    required this.emotions,
    this.updatedAt,
  });

  final DeviceStatus device;
  final EegData? latestEeg;
  final List<EmotionScore> emotions;
  final String? updatedAt;

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    final emotionMap = json['emotions'] as Map<String, dynamic>? ?? {};
    final emotions = emotionMap.entries
        .map((entry) => EmotionScore.fromJson(entry.key, entry.value))
        .toList(growable: false);

    final eegJson = json['latest_eeg'] as Map<String, dynamic>?;

    return AppSnapshot(
      device: DeviceStatus.fromJson(
        json['device'] as Map<String, dynamic>? ?? {},
      ),
      latestEeg: eegJson == null ? null : EegData.fromJson(eegJson),
      emotions: emotions,
      updatedAt: json['updated_at'] as String?,
    );
  }

  static AppSnapshot empty() {
    return AppSnapshot(
      device: const DeviceStatus(
        connected: false,
        message: 'Bağlantı bekleniyor',
      ),
      emotions: const [],
    );
  }
}
