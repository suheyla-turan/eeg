import '../models/text_content.dart';

abstract class TextRepository {
  Future<List<TextContent>> getAll();

  Future<List<TextContent>> getActive();

  Future<TextContent?> getById(String textId);
}
