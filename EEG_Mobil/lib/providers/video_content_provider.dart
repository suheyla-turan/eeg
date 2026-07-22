import 'package:flutter/foundation.dart';

import '../models/video_content.dart';
import '../repositories/video_repository.dart';

class VideoContentProvider extends ChangeNotifier {
  VideoContentProvider({required VideoRepository repository})
      : _repository = repository;

  final VideoRepository _repository;

  List<VideoContent> videos = [];
  bool loading = false;
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
}
