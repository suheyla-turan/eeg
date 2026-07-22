import '../core/app_logger.dart';
import '../models/experiment.dart';
import '../models/experiment_result.dart';
import '../models/video_watch_event.dart';
import '../repositories/eeg_storage_repository.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/result_repository.dart';
import '../repositories/video_watch_event_repository.dart';
import 'gemini_session_service.dart';
import 'result_calculator.dart';

/// Eski deney sonuçlarını Storage'daki ham EEG üzerinden yeniden yorumlar.
///
/// Firestore'daki sonuç [ResultCalculator.analysisVersion] altındaysa
/// `eeg/{id}/eeg.json` indirilir, spektral analiz (v3) uygulanır ve sonuç
/// güncellenir. Geçmiş listesi yüklenirken toplu yükseltme yapılabilir.
///
/// Spektral güncellemeden sonra (veya açılışta) Gemini yorumu yoksa
/// [GeminiSessionService] ile üretilir.
class ResultReanalyzer {
  ResultReanalyzer({
    required EegStorageRepository storage,
    required ResultRepository results,
    VideoWatchEventRepository? watchEvents,
    ExperimentRepository? experiments,
    ResultCalculator? calculator,
    GeminiSessionService? gemini,
  })  : _storage = storage,
        _results = results,
        _watchEvents = watchEvents,
        _experiments = experiments,
        _calculator = calculator ?? ResultCalculator(),
        _gemini = gemini;

  final EegStorageRepository _storage;
  final ResultRepository _results;
  final VideoWatchEventRepository? _watchEvents;
  final ExperimentRepository? _experiments;
  final ResultCalculator _calculator;
  final GeminiSessionService? _gemini;

  /// Gerekirse yeniden hesaplar; aksi halde mevcut sonucu döner.
  Future<ExperimentResult> ensureCurrentAnalysis({
    required Experiment experiment,
    required ExperimentResult existing,
  }) async {
    if (existing.analysisVersion >= ResultCalculator.analysisVersion) {
      return existing;
    }

    final upgraded = await _recomputeFromStorage(
      experiment: experiment,
      existing: existing,
    );
    return upgraded ?? existing;
  }

  /// Deney için sonucu bulur (resultId veya experimentId) ve gerekirse
  /// spektral analize yükseltir; ardından Gemini yorumunu üretir.
  /// Storage yoksa null.
  Future<ExperimentResult?> ensureCurrentForExperiment(
    Experiment experiment, {
    bool withGemini = true,
  }) async {
    var existing = await _resolveResult(experiment);

    if (existing == null ||
        existing.analysisVersion < ResultCalculator.analysisVersion) {
      final recomputed = await _recomputeFromStorage(
        experiment: experiment,
        existing: existing,
      );
      existing = recomputed ?? existing;
    }

    if (existing == null) return null;
    if (!withGemini) return existing;

    final gemini = _gemini;
    if (gemini == null) return existing;
    return gemini.ensureInterpretation(existing);
  }

  /// Birden fazla deneyi v3'e yükseltir (geçmiş yüklenirken).
  Future<ReanalysisSummary> upgradeExperiments(
    List<Experiment> experiments,
  ) async {
    var upgraded = 0;
    var alreadyCurrent = 0;
    var skipped = 0;
    var failed = 0;

    for (final exp in experiments) {
      // Sonuç veya storage yoksa atla
      final hasResult = (exp.resultId != null && exp.resultId!.isNotEmpty) ||
          (exp.storagePath != null && exp.storagePath!.isNotEmpty);
      if (!hasResult) {
        skipped++;
        continue;
      }

      try {
        final before = await _resolveResult(exp);
        if (before != null &&
            before.analysisVersion >= ResultCalculator.analysisVersion) {
          alreadyCurrent++;
          continue;
        }

        final after = await ensureCurrentForExperiment(exp, withGemini: false);
        if (after == null) {
          skipped++;
        } else if (before == null ||
            after.analysisVersion > (before.analysisVersion)) {
          upgraded++;
        } else if (after.analysisVersion >=
            ResultCalculator.analysisVersion) {
          alreadyCurrent++;
        } else {
          skipped++;
        }
      } catch (e, st) {
        failed++;
        AppLogger.instance.error(
          'Yeniden analiz başarısız: ${exp.experimentId}',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (upgraded > 0) {
      AppLogger.instance.experiment(
        'Toplu yeniden analiz: $upgraded yükseltildi, '
        '$alreadyCurrent güncel, $skipped atlandı, $failed hata',
      );
    }

    return ReanalysisSummary(
      upgraded: upgraded,
      alreadyCurrent: alreadyCurrent,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<ExperimentResult?> _resolveResult(Experiment experiment) async {
    if (experiment.resultId != null && experiment.resultId!.isNotEmpty) {
      final byId = await _results.getById(experiment.resultId!);
      if (byId != null) return byId;
    }
    return _results.getByExperimentId(experiment.experimentId);
  }

  Future<ExperimentResult?> _recomputeFromStorage({
    required Experiment experiment,
    ExperimentResult? existing,
  }) async {
    final folder = experiment.storagePath;
    if (folder == null || folder.isEmpty) {
      AppLogger.instance.experiment(
        'Yeniden analiz atlandı (storage yok): ${experiment.experimentId}',
      );
      return null;
    }

    final jsonPath =
        folder.endsWith('.json') ? folder : '$folder/eeg.json';

    final payload = await _storage.downloadJson(jsonPath);
    if (payload == null) {
      AppLogger.instance.experiment(
        'Yeniden analiz atlandı (JSON yok): $jsonPath',
      );
      return null;
    }

    final rawSamples = payload['samples'];
    if (rawSamples is! List || rawSamples.isEmpty) {
      AppLogger.instance.experiment(
        'Yeniden analiz atlandı (örnek yok): ${experiment.experimentId}',
      );
      return null;
    }

    final samples = rawSamples
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    List<VideoWatchEvent> watchEvents = const [];
    final watchRepo = _watchEvents;
    if (watchRepo != null) {
      try {
        watchEvents =
            await watchRepo.getByExperimentId(experiment.experimentId);
      } catch (_) {}
    }

    final recomputed = _calculator.calculateFromSamples(
      experimentId: experiment.experimentId,
      participantId: experiment.participantId,
      samples: samples,
      watchEvents: watchEvents,
      preserveVideoStats: watchEvents.isEmpty && existing != null
          ? existing.videoStats
          : null,
      resultId: existing?.resultId ?? '',
      createdAt: existing?.createdAt ?? experiment.createdAt,
    );

    // Spektral metrikler değişti; eski Gemini yorumu geçersiz.
    final draft = recomputed.copyWith(
      resultId: existing?.resultId ?? recomputed.resultId,
      clearGemini: true,
    );

    final ExperimentResult saved;
    if (existing != null && existing.resultId.isNotEmpty) {
      saved = await _results.update(draft);
    } else {
      saved = await _results.create(draft);
      // Deney kaydına resultId bağla
      final expRepo = _experiments;
      if (expRepo != null && saved.resultId.isNotEmpty) {
        try {
          await expRepo.update(
            experiment.copyWith(resultId: saved.resultId),
          );
        } catch (_) {}
      }
    }

    AppLogger.instance.experiment(
      'Sonuç spektral olarak yeniden yorumlandı: ${saved.resultId} '
      '(v${existing?.analysisVersion ?? 0}→v${saved.analysisVersion})',
    );
    return saved;
  }
}

class ReanalysisSummary {
  const ReanalysisSummary({
    this.upgraded = 0,
    this.alreadyCurrent = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final int upgraded;
  final int alreadyCurrent;
  final int skipped;
  final int failed;

  int get total => upgraded + alreadyCurrent + skipped + failed;

  bool get didUpgrade => upgraded > 0;
}
