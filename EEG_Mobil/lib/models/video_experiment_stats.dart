/// Reels aşamasına ait izleme istatistikleri.
class VideoExperimentStats {
  final int totalVideos;
  final int totalScrolls;
  final int rewatchedVideos;
  final double averageWatchSeconds;
  final Map<String, int> categoryWatchSeconds;
  final int totalWatchSeconds;

  const VideoExperimentStats({
    this.totalVideos = 0,
    this.totalScrolls = 0,
    this.rewatchedVideos = 0,
    this.averageWatchSeconds = 0,
    this.categoryWatchSeconds = const {},
    this.totalWatchSeconds = 0,
  });

  static const empty = VideoExperimentStats();

  Map<String, dynamic> toMap() {
    return {
      'totalVideos': totalVideos,
      'totalScrolls': totalScrolls,
      'rewatchedVideos': rewatchedVideos,
      'averageWatchSeconds': averageWatchSeconds,
      'categoryWatchSeconds': categoryWatchSeconds,
      'totalWatchSeconds': totalWatchSeconds,
    };
  }

  factory VideoExperimentStats.fromMap(Map<String, dynamic> map) {
    final rawCats = map['categoryWatchSeconds'];
    final cats = <String, int>{};
    if (rawCats is Map) {
      for (final e in rawCats.entries) {
        cats['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return VideoExperimentStats(
      totalVideos: (map['totalVideos'] as num?)?.toInt() ?? 0,
      totalScrolls: (map['totalScrolls'] as num?)?.toInt() ?? 0,
      rewatchedVideos: (map['rewatchedVideos'] as num?)?.toInt() ?? 0,
      averageWatchSeconds:
          (map['averageWatchSeconds'] as num?)?.toDouble() ?? 0,
      categoryWatchSeconds: cats,
      totalWatchSeconds: (map['totalWatchSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
