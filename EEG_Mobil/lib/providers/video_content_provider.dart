import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/video_content.dart';
import '../repositories/video_repository.dart';

class VideoContentProvider extends ChangeNotifier {
  VideoContentProvider({required VideoRepository repository})
      : _repository = repository;

  final VideoRepository _repository;

  List<VideoContent> videos = [];
  bool loading = false;
  bool saving = false;
  String? errorMessage;

  Future<void> loadAll() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      videos = await _repository.getAll();
    } catch (e) {
      errorMessage = e.toString();
      if (kDebugMode) debugPrint('Video load: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<VideoContent?> create({
    required String title,
    required String description,
    required String category,
    required int duration,
    required bool active,
    required File videoFile,
    File? thumbnailFile,
  }) async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final draft = VideoContent(
        videoId: '',
        title: title,
        description: description,
        category: category,
        storageUrl: '',
        duration: duration,
        active: active,
        createdAt: DateTime.now(),
      );
      final created = await _repository.create(draft);
      final url = await _repository.uploadVideoFile(
        videoId: created.videoId,
        file: videoFile,
      );
      String? thumbUrl;
      if (thumbnailFile != null) {
        thumbUrl = await _repository.uploadThumbnailFile(
          videoId: created.videoId,
          file: thumbnailFile,
        );
      }
      final updated = created.copyWith(
        storageUrl: url,
        thumbnail: thumbUrl,
      );
      await _repository.update(updated);
      await loadAll();
      return updated;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateVideo({
    required VideoContent video,
    File? newVideoFile,
    File? newThumbnailFile,
  }) async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      var next = video;
      if (newVideoFile != null) {
        final url = await _repository.uploadVideoFile(
          videoId: video.videoId,
          file: newVideoFile,
        );
        next = next.copyWith(storageUrl: url);
      }
      if (newThumbnailFile != null) {
        final thumb = await _repository.uploadThumbnailFile(
          videoId: video.videoId,
          file: newThumbnailFile,
        );
        next = next.copyWith(thumbnail: thumb);
      }
      await _repository.update(next);
      await loadAll();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String videoId) async {
    errorMessage = null;
    try {
      await _repository.delete(videoId);
      videos.removeWhere((v) => v.videoId == videoId);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
