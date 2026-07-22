import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_logger.dart';
import '../../models/text_quiz_response.dart';
import '../text_quiz_response_repository.dart';

class FirebaseTextQuizResponseRepository
    implements TextQuizResponseRepository {
  FirebaseTextQuizResponseRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('text_quiz_responses');

  @override
  Future<TextQuizResponse> create(TextQuizResponse response) async {
    try {
      final doc = _col.doc();
      final created = TextQuizResponse(
        responseId: doc.id,
        experimentId: response.experimentId,
        textId: response.textId,
        answers: response.answers,
        moodOption: response.moodOption,
        moodOptions: response.moodOptions,
        moodOtherText: response.moodOtherText,
        createdAt: response.createdAt,
      );
      await doc.set(created.toMap());
      AppLogger.instance.firebase(
        'Text quiz response kaydedildi: ${created.responseId}',
      );
      return created;
    } catch (e, st) {
      AppLogger.instance.error(
        'Text quiz response create hatası',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<TextQuizResponse>> getByExperimentId(String experimentId) async {
    final snap =
        await _col.where('experimentId', isEqualTo: experimentId).get();
    final list = snap.docs
        .map((d) => TextQuizResponse.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}
