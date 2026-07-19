import 'package:cloud_firestore/cloud_firestore.dart';

import 'experiment_status.dart';

class Experiment {
  final String experimentId;
  final String participantId;
  final String experimentType;
  final String? videoId;
  final String? textId;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? duration;
  final bool completed;
  final String status;
  final String? storagePath;
  final String? csvStoragePath;
  final String? resultId;
  final String? cancelReason;
  final DateTime createdAt;

  const Experiment({
    required this.experimentId,
    required this.participantId,
    required this.experimentType,
    this.videoId,
    this.textId,
    this.startTime,
    this.endTime,
    this.duration,
    this.completed = false,
    this.status = ExperimentStatus.pending,
    this.storagePath,
    this.csvStoragePath,
    this.resultId,
    this.cancelReason,
    required this.createdAt,
  });

  bool get isCancelled => status == ExperimentStatus.cancelled;

  Map<String, dynamic> toMap() {
    return {
      'experimentId': experimentId,
      'participantId': participantId,
      'experimentType': experimentType,
      'videoId': videoId,
      'textId': textId,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration,
      'completed': completed,
      'status': status,
      'storagePath': storagePath,
      'csvStoragePath': csvStoragePath,
      'resultId': resultId,
      'cancelReason': cancelReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Experiment.fromMap(Map<String, dynamic> map, {String? id}) {
    final completed = map['completed'] as bool? ?? false;
    final rawStatus = map['status'] as String?;
    final status = rawStatus ??
        (completed
            ? ExperimentStatus.completed
            : ExperimentStatus.pending);

    return Experiment(
      experimentId: id ?? map['experimentId'] as String? ?? '',
      participantId: map['participantId'] as String? ?? '',
      experimentType: map['experimentType'] as String? ?? 'full_protocol',
      videoId: map['videoId'] as String?,
      textId: map['textId'] as String?,
      startTime: _readDateOrNull(map['startTime']),
      endTime: _readDateOrNull(map['endTime']),
      duration: (map['duration'] as num?)?.toInt(),
      completed: completed,
      status: status,
      storagePath: map['storagePath'] as String?,
      csvStoragePath: map['csvStoragePath'] as String?,
      resultId: map['resultId'] as String?,
      cancelReason: map['cancelReason'] as String?,
      createdAt: _readDate(map['createdAt']),
    );
  }

  Experiment copyWith({
    String? experimentId,
    String? participantId,
    String? experimentType,
    String? videoId,
    String? textId,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    bool? completed,
    String? status,
    String? storagePath,
    String? csvStoragePath,
    String? resultId,
    String? cancelReason,
    DateTime? createdAt,
  }) {
    return Experiment(
      experimentId: experimentId ?? this.experimentId,
      participantId: participantId ?? this.participantId,
      experimentType: experimentType ?? this.experimentType,
      videoId: videoId ?? this.videoId,
      textId: textId ?? this.textId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      completed: completed ?? this.completed,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
      csvStoragePath: csvStoragePath ?? this.csvStoragePath,
      resultId: resultId ?? this.resultId,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

DateTime? _readDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
