import '../models/text_quiz_response.dart';

abstract class TextQuizResponseRepository {
  Future<TextQuizResponse> create(TextQuizResponse response);

  Future<List<TextQuizResponse>> getByExperimentId(String experimentId);
}
