import '../models/video_content.dart';

abstract class VideoRepository {
  Future<List<VideoContent>> getAll();

  Future<List<VideoContent>> getActive();

  Future<VideoContent?> getById(String videoId);
}
