import '../models/video_watch_event.dart';

abstract class VideoWatchEventRepository {
  Future<VideoWatchEvent> create(VideoWatchEvent event);

  Future<List<VideoWatchEvent>> getByExperimentId(String experimentId);
}
