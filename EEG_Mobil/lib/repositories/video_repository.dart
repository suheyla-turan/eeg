import 'dart:io';

import '../models/video_content.dart';

abstract class VideoRepository {
  Future<List<VideoContent>> getAll();

  Future<List<VideoContent>> getActive();

  Future<VideoContent?> getById(String videoId);

  Future<VideoContent> create(VideoContent video);

  Future<void> update(VideoContent video);

  Future<void> delete(String videoId);

  /// Firestore `videos` koleksiyonunu ve Storage `videos/` klasörünü tamamen siler.
  /// Silinen Firestore belge sayısını döner.
  Future<int> deleteAll();

  /// Video dosyasını Firebase Storage'a yükler; indirme URL'si döner.
  Future<String> uploadVideoFile({
    required String videoId,
    required File file,
  });

  /// Küçük resmi Firebase Storage'a yükler; indirme URL'si döner.
  Future<String> uploadThumbnailFile({
    required String videoId,
    required File file,
  });
}
