import 'package:cloud_firestore/cloud_firestore.dart';

/// Reels deneyinde her video için izleme kaydı.
class VideoWatchEvent {
  final String eventId;
  final String experimentId;
  final String videoId;
  final DateTime startTime;
  final DateTime endTime;
  final int watchDurationSeconds;
  final double percentWatched;
  final int replayCount;
  final DateTime transitionTime;
  final String category;

  const VideoWatchEvent({
    required this.eventId,
    required this.experimentId,
    required this.videoId,
    required this.startTime,
    required this.endTime,
    required this.watchDurationSeconds,
    required this.percentWatched,
    this.replayCount = 0,
    required this.transitionTime,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'experimentId': experimentId,
      'videoId': videoId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'watchDurationSeconds': watchDurationSeconds,
      'percentWatched': percentWatched,
      'replayCount': replayCount,
      'transitionTime': Timestamp.fromDate(transitionTime),
      'category': category,
    };
  }

  factory VideoWatchEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    return VideoWatchEvent(
      eventId: id ?? map['eventId'] as String? ?? '',
      experimentId: map['experimentId'] as String? ?? '',
      videoId: map['videoId'] as String? ?? '',
      startTime: _readDate(map['startTime']),
      endTime: _readDate(map['endTime']),
      watchDurationSeconds: (map['watchDurationSeconds'] as num?)?.toInt() ?? 0,
      percentWatched: (map['percentWatched'] as num?)?.toDouble() ?? 0,
      replayCount: (map['replayCount'] as num?)?.toInt() ?? 0,
      transitionTime: _readDate(map['transitionTime']),
      category: map['category'] as String? ?? '',
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
