import '../models/text_content.dart';

abstract class TextRepository {
  Future<List<TextContent>> getAll();

  Future<List<TextContent>> getActive();

  Future<TextContent?> getById(String textId);

  Future<TextContent> create(TextContent text);

  Future<void> update(TextContent text);

  Future<void> delete(String textId);
}
