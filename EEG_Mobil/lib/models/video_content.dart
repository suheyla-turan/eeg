import 'package:cloud_firestore/cloud_firestore.dart';

class VideoContent {
  final String videoId;
  final String title;
  final String description;
  final String category;
  final String storageUrl;
  final String? thumbnail;
  final int duration;
  final bool active;
  final DateTime createdAt;

  const VideoContent({
    required this.videoId,
    required this.title,
    required this.description,
    this.category = '',
    required this.storageUrl,
    this.thumbnail,
    required this.duration,
    this.active = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'description': description,
      'category': category,
      'storageUrl': storageUrl,
      'thumbnail': thumbnail,
      'duration': duration,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory VideoContent.fromMap(Map<String, dynamic> map, {String? id}) {
    return VideoContent(
      videoId: id ?? map['videoId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      storageUrl: map['storageUrl'] as String? ?? '',
      thumbnail: map['thumbnail'] as String?,
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      active: _readActive(map['active']),
      createdAt: _readDate(map['createdAt']),
    );
  }

  VideoContent copyWith({
    String? videoId,
    String? title,
    String? description,
    String? category,
    String? storageUrl,
    String? thumbnail,
    int? duration,
    bool? active,
    DateTime? createdAt,
  }) {
    return VideoContent(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      storageUrl: storageUrl ?? this.storageUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

bool _readActive(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'false' || v == '0' || v == 'no' || v == 'pasif') return false;
    if (v == 'true' || v == '1' || v == 'yes' || v == 'aktif') return true;
  }
  // Alan yoksa veya tanınmıyorsa aktif kabul et (liste ekranıyla uyumlu).
  return true;
}
