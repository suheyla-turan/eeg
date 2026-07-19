import 'package:flutter/foundation.dart';

import '../models/text_content.dart';
import '../repositories/text_repository.dart';

class TextContentProvider extends ChangeNotifier {
  TextContentProvider({required TextRepository repository})
      : _repository = repository;

  final TextRepository _repository;

  List<TextContent> texts = [];
  bool loading = false;
  bool saving = false;
  String? errorMessage;

  Future<void> loadAll() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      texts = await _repository.getAll();
    } catch (e) {
      errorMessage = e.toString();
      if (kDebugMode) debugPrint('Text load: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<TextContent?> create({
    required String title,
    required String content,
    required String difficulty,
    required int estimatedDuration,
    required bool active,
  }) async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final created = await _repository.create(
        TextContent(
          textId: '',
          title: title,
          content: content,
          difficulty: difficulty,
          estimatedDuration: estimatedDuration,
          active: active,
          createdAt: DateTime.now(),
        ),
      );
      await loadAll();
      return created;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateText(TextContent text) async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.update(text);
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

  Future<bool> delete(String textId) async {
    errorMessage = null;
    try {
      await _repository.delete(textId);
      texts.removeWhere((t) => t.textId == textId);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
