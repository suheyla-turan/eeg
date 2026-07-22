import 'package:flutter/foundation.dart';

import '../models/text_content.dart';
import '../repositories/text_repository.dart';

class TextContentProvider extends ChangeNotifier {
  TextContentProvider({required TextRepository repository})
      : _repository = repository;

  final TextRepository _repository;

  List<TextContent> texts = [];
  bool loading = false;
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
}
