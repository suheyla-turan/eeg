import '../core/app_logger.dart';
import '../models/experiment_result.dart';
import '../repositories/result_repository.dart';
import 'eeg_api_service.dart';

/// Deney sonucunu PC API üzerinden Gemini ile yorumlar ve Firestore'a kaydeder.
class GeminiSessionService {
  GeminiSessionService({
    required EegApiService api,
    required ResultRepository results,
  })  : _api = api,
        _results = results;

  final EegApiService _api;
  final ResultRepository _results;

  /// Zaten Gemini yorumu varsa dokunmaz; yoksa üretir ve kaydeder.
  ///
  /// Başarısız olursa [existing] döner; hata metni [lastError]'a yazılır.
  String? lastError;

  Future<ExperimentResult> ensureInterpretation(ExperimentResult existing) async {
    lastError = null;
    if (existing.hasGeminiInterpretation) return existing;

    try {
      final response = await _api.analyzeSession(buildPayload(existing));
      if (!response.ok || response.markdown.trim().isEmpty) {
        lastError = response.error?.trim().isNotEmpty == true
            ? response.error
            : 'Boş yanıt (model veya kota sorunu olabilir)';
        AppLogger.instance.experiment(
          'Gemini yorumu alınamadı: $lastError',
        );
        return existing;
      }

      final updated = existing.copyWith(
        geminiMarkdown: response.markdown.trim(),
        geminiModel: response.model,
        geminiAnalyzedAt: DateTime.now(),
      );

      if (updated.resultId.isEmpty) return updated;
      final saved = await _results.update(updated);
      AppLogger.instance.experiment(
        'Gemini yorumu kaydedildi: ${saved.resultId} (${saved.geminiModel})',
      );
      return saved;
    } catch (e, st) {
      lastError = e.toString();
      AppLogger.instance.error(
        'Gemini oturum analizi başarısız: ${existing.experimentId}',
        error: e,
        stackTrace: st,
      );
      return existing;
    }
  }

  /// API [SessionAnalysisRequest] gövdesi.
  static Map<String, dynamic> buildPayload(ExperimentResult result) {
    return {
      'experimentId': result.experimentId,
      'participantId': result.participantId,
      'analysisVersion': result.analysisVersion,
      'dataInsufficient': result.dataInsufficient,
      'dataInsufficientReason': result.dataInsufficientReason,
      'reels': result.reels.toMap(),
      'text': result.text.toMap(),
      'attentionSeries': result.attentionSeries,
      'focusSeries': result.focusSeries,
      'stressSeries': result.stressSeries,
      'engagementSeries': result.engagementSeries,
      'maxOutputTokens': 4096,
    };
  }
}
