import '../data/local_videos.dart';
import '../models/video_content.dart';
import 'video_repository.dart';

/// Videoları uygulama asset'lerinden okur; ekleme/silme yok.
class AssetVideoRepository implements VideoRepository {
  AssetVideoRepository({List<LocalVideoEntry>? entries})
      : _videos = List<VideoContent>.unmodifiable(
          (entries ?? kLocalVideos).map((e) => e.toVideoContent()),
        );

  final List<VideoContent> _videos;

  @override
  Future<List<VideoContent>> getAll() async => List<VideoContent>.from(_videos);

  @override
  Future<List<VideoContent>> getActive() async {
    return _videos
        .where((v) => v.active && v.storageUrl.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<VideoContent?> getById(String videoId) async {
    for (final v in _videos) {
      if (v.videoId == videoId) return v;
    }
    return null;
  }
}
