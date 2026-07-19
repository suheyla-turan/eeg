import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/video_content.dart';
import '../repositories/firebase/firebase_video_repository.dart';
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
      await _tryAnonymousAuth();
      final updated = await _createOne(
        title: title,
        description: description,
        category: category,
        duration: duration,
        active: active,
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
      );
      await loadAll();
      return updated;
    } catch (e) {
      errorMessage = _friendlyFirebaseError(e);
      notifyListeners();
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Galeriden seçilen videoları form olmadan yükler.
  /// Başlık dosya adından alınır; diğer alanlar varsayılan kalır.
  Future<({int uploaded, int failed})> createManyFromFiles(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (files.isEmpty) return (uploaded: 0, failed: 0);

    saving = true;
    errorMessage = null;
    notifyListeners();

    var uploaded = 0;
    var failed = 0;
    try {
      await _tryAnonymousAuth();
      for (var i = 0; i < files.length; i++) {
        onProgress?.call(i + 1, files.length);
        try {
          await _createOne(
            title: _titleFromPath(files[i].path),
            description: '',
            category: '',
            duration: 0,
            active: true,
            videoFile: files[i],
          );
          uploaded++;
        } catch (e) {
          failed++;
          if (kDebugMode) debugPrint('Video upload failed: $e');
          errorMessage = _friendlyFirebaseError(e);
        }
      }
      await loadAll();
      if (failed > 0 && errorMessage == null) {
        errorMessage = '$failed video yüklenemedi';
      }
      return (uploaded: uploaded, failed: failed);
    } catch (e) {
      errorMessage = _friendlyFirebaseError(e);
      if (kDebugMode) debugPrint('Video upload aborted: $e');
      return (uploaded: uploaded, failed: files.length - uploaded);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<VideoContent> _createOne({
    required String title,
    required String description,
    required String category,
    required int duration,
    required bool active,
    required File videoFile,
    File? thumbnailFile,
  }) async {
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
    try {
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
      return updated;
    } catch (e) {
      // Storage yüklemesi başarısızsa yarım kalan Firestore kaydını sil.
      // Storage listesi 403 verebileceği için yalnızca metadata silinir.
      try {
        final repo = _repository;
        if (repo is FirebaseVideoRepository) {
          await repo.deleteMetadata(created.videoId);
        } else {
          await _repository.delete(created.videoId);
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Auth isteğe bağlı; Console'da Anonymous kapalıysa yükleme yine denenir.
  Future<void> _tryAnonymousAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;
    try {
      await auth.signInAnonymously();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Anonim Auth atlandı (Console\'da Enable edilmeli): $e',
        );
      }
    }
  }

  String _friendlyFirebaseError(Object e) {
    final text = e.toString();
    if (text.contains('permission-denied') ||
        text.contains('unauthorized') ||
        text.contains('admin-restricted-operation')) {
      return 'Firebase izni yok. Console\'da Firestore + Storage Rules '
          'için "allow read, write: if true;" yayınla; '
          'Authentication → Anonymous\'ı Enable et.';
    }
    return text;
  }

  String _titleFromPath(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name.isEmpty ? 'Video' : name;
    final base = name.substring(0, dot).trim();
    return base.isEmpty ? 'Video' : base;
  }

  Future<bool> rename(String videoId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'İsim boş olamaz';
      notifyListeners();
      return false;
    }

    final index = videos.indexWhere((v) => v.videoId == videoId);
    if (index < 0) {
      errorMessage = 'Video bulunamadı';
      notifyListeners();
      return false;
    }

    errorMessage = null;
    try {
      final updated = videos[index].copyWith(title: trimmed);
      await _repository.update(updated);
      videos[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
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

  /// Firestore + Storage'daki tüm videoları siler.
  Future<int?> deleteAll() async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final count = await _repository.deleteAll();
      videos = [];
      return count;
    } catch (e) {
      errorMessage = e.toString();
      if (kDebugMode) debugPrint('Video deleteAll: $e');
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
