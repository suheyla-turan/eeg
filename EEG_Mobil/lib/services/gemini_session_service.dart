import '../core/app_logger.dart';
import '../models/experiment_result.dart';
import '../models/participant.dart';
import '../repositories/participant_repository.dart';
import '../repositories/result_repository.dart';
import 'eeg_api_service.dart';

/// Deney sonucunu PC API üzerinden Gemini ile yorumlar ve Firestore'a kaydeder.
class GeminiSessionService {
  GeminiSessionService({
    required EegApiService api,
    required ResultRepository results,
    ParticipantRepository? participants,
  })  : _api = api,
        _results = results,
        _participants = participants;

  final EegApiService _api;
  final ResultRepository _results;
  final ParticipantRepository? _participants;

  /// Zaten Gemini yorumu varsa dokunmaz; yoksa üretir ve kaydeder.
  ///
  /// Başarısız olursa [existing] döner; hata metni [lastError]'a yazılır.
  String? lastError;

  Future<ExperimentResult> ensureInterpretation(
    ExperimentResult existing, {
    Participant? participant,
  }) async {
    lastError = null;
    if (existing.hasGeminiInterpretation) return existing;

    try {
      final profile = participant ??
          await _resolveParticipant(existing.participantId);
      final response = await _api.analyzeSession(
        buildPayload(existing, participant: profile),
      );
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

  Future<Participant?> _resolveParticipant(String participantId) async {
    if (participantId.isEmpty) return null;
    final repo = _participants;
    if (repo == null) return null;
    try {
      return await repo.getById(participantId);
    } catch (_) {
      return null;
    }
  }

  /// API [SessionAnalysisRequest] gövdesi.
  static Map<String, dynamic> buildPayload(
    ExperimentResult result, {
    Participant? participant,
  }) {
    return {
      'experimentId': result.experimentId,
      'participantId': result.participantId,
      'analysisVersion': result.analysisVersion,
      'dataInsufficient': result.dataInsufficient,
      'dataInsufficientReason': result.dataInsufficientReason,
      if (participant != null) 'participant': participantToProfileMap(participant),
      'reels': result.reels.toMap(),
      'text': result.text.toMap(),
      'attentionSeries': result.attentionSeries,
      'focusSeries': result.focusSeries,
      'stressSeries': result.stressSeries,
      'engagementSeries': result.engagementSeries,
      'maxOutputTokens': 6144,
    };
  }

  /// Gemini'ye giden demografik alanlar (isim gönderilmez).
  static Map<String, dynamic> participantToProfileMap(Participant p) {
    return {
      'participantCode': p.participantCode,
      'age': p.age,
      'gender': p.gender,
      'education': p.education,
      'occupation': p.occupation,
      'dailySocialMediaUsage': p.dailySocialMediaUsage,
      'dominantHand': p.dominantHand,
      'visionProblem': p.visionProblem,
      'sleepDuration': p.sleepDuration,
      'notes': p.notes,
    };
  }
}
