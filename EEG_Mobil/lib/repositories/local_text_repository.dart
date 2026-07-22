import '../data/local_texts.dart';
import '../models/text_content.dart';
import 'text_repository.dart';

/// Metinleri kod içindeki listeden okur; ekleme/silme yok.
class LocalTextRepository implements TextRepository {
  LocalTextRepository({List<LocalTextEntry>? entries})
      : _texts = List<TextContent>.unmodifiable(
          (entries ?? kLocalTexts).map((e) => e.toTextContent()),
        );

  final List<TextContent> _texts;

  @override
  Future<List<TextContent>> getAll() async => List<TextContent>.from(_texts);

  @override
  Future<List<TextContent>> getActive() async {
    return _texts.where((t) => t.active).toList(growable: false);
  }

  @override
  Future<TextContent?> getById(String textId) async {
    for (final t in _texts) {
      if (t.textId == textId) return t;
    }
    return null;
  }
}
