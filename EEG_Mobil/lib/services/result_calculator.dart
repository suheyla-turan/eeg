import '../models/experiment_result.dart';
import '../models/phase_metrics.dart';
import '../models/video_experiment_stats.dart';
import '../models/video_watch_event.dart';
import 'eeg_buffer_service.dart';
import 'spectral_eeg_analyzer.dart';

/// Buffer örneklerinden bilimsel EEG tabanlı özet sonuç üretir.
///
/// Pipeline dışı hesaplama YOKTUR. DEV stream (signal / CQ) skorlara girmez;
/// overallQuality yalnızca epoch kabul/red kararında kullanılır.
///
/// [analysisVersion] 3 = Welch + baseline-relative + bağımsız distraction.
class ResultCalculator {
  /// 1 = eski kalite proxy; 2 = magic-scale; 3–4 = Welch;
  /// 5 = EEG-stream tanı mesajı + spektral öncelik
  static const int analysisVersion = 5;

  ExperimentResult calculate({
    required String experimentId,
    required String participantId,
    required EegBufferService buffer,
    List<VideoWatchEvent> watchEvents = const [],
    VideoExperimentStats? preserveVideoStats,
    String? resultId,
    DateTime? createdAt,
  }) {
    final all = buffer.samples;
    final baselineSamples = buffer.samplesForPhase('baseline');
    final reelsSamples = buffer.samplesForPhase('reels');
    final textSamples = buffer.samplesForPhase('text');

    final baseline = _metricsFor(baselineSamples, phase: 'baseline');
    final reels = _metricsFor(
      reelsSamples,
      phase: 'reels',
      baselineBands: _bandsOrNull(baselineSamples),
    );
    final text = _metricsFor(
      textSamples,
      phase: 'text',
      baselineBands: _bandsOrNull(baselineSamples),
    );
    final overall = _metricsFor(
      all,
      phase: 'overall',
      baselineBands: _bandsOrNull(baselineSamples),
    );

    final videoStats = preserveVideoStats ?? _videoStats(watchEvents);

    final bands = SpectralEegAnalyzer.bandsForSamples(all);
    final scores = SpectralEegAnalyzer.scoresFromBands(
      bands,
      attentionRaw: SpectralEegAnalyzer.attentionBandsForSamples(all),
    );
    final features = scores.features;
    final rel = bands.relative();

    // Baseline-relative attention değişimi (%)
    // Örn. +18 → görevde baseline'a göre %18 daha yüksek attention skoru.
    // Baseline adımı yoksa / örnek yoksa NaN → UI "Baseline verisi bulunamadı".
    final hasBaselineData = baseline.sampleCount > 0 &&
        !baseline.dataInsufficient &&
        baseline.attention > 1e-6;
    final taskAttention = _avgNonZero([reels.attention, text.attention]);
    final baselineDiff = hasBaselineData
        ? SpectralEegAnalyzer.percentChange(
            taskAttention,
            baseline.attention,
          )
        : double.nan;

    final series = _epochSeries(all);

    final insufficient = !bands.hasPower || !scores.sufficientData;
    final reason = insufficient
        ? SpectralEegAnalyzer.insufficientReason(all)
        : '';

    return ExperimentResult(
      resultId: resultId ?? '',
      experimentId: experimentId,
      participantId: participantId,
      averageAttention: overall.attention,
      averageFocus: overall.focus,
      averageStress: overall.stress,
      averageRelaxation: overall.relaxation,
      averageInterest: overall.interest,
      averageEngagement: overall.engagement,
      averageExcitement: overall.excitement,
      alphaPower: rel.alpha * 100,
      betaPower: rel.beta * 100,
      thetaPower: rel.theta * 100,
      deltaPower: rel.delta * 100,
      gammaPower: rel.gamma * 100,
      mentalFatigue: scores.mentalFatigue,
      // Bağımsız distraction — 100−focus değil
      distractionScore: scores.distraction,
      baselineDifference: baselineDiff,
      focusScore: overall.focus,
      thetaBetaRatio: features.thetaBeta,
      alphaBetaRatio: features.alphaBeta,
      betaAlphaRatio: features.betaAlpha,
      dataInsufficient: insufficient,
      dataInsufficientReason: reason,
      baseline: baseline,
      reels: reels,
      text: text,
      videoStats: videoStats,
      attentionSeries: series.attention,
      focusSeries: series.focus,
      stressSeries: series.stress,
      engagementSeries: series.engagement,
      createdAt: createdAt ?? DateTime.now(),
      analysisVersion: analysisVersion,
    );
  }

  ExperimentResult calculateFromSamples({
    required String experimentId,
    required String participantId,
    required List<Map<String, dynamic>> samples,
    List<VideoWatchEvent> watchEvents = const [],
    VideoExperimentStats? preserveVideoStats,
    String? resultId,
    DateTime? createdAt,
  }) {
    final buffer = EegBufferService()..restoreSamples(samples);
    return calculate(
      experimentId: experimentId,
      participantId: participantId,
      buffer: buffer,
      watchEvents: watchEvents,
      preserveVideoStats: preserveVideoStats,
      resultId: resultId,
      createdAt: createdAt,
    );
  }

  SpectralBands? _bandsOrNull(List<Map<String, dynamic>> samples) {
    final b = SpectralEegAnalyzer.bandsForSamples(samples);
    return b.hasPower ? b : null;
  }

  PhaseMetrics _metricsFor(
    List<Map<String, dynamic>> samples, {
    required String phase,
    SpectralBands? baselineBands,
  }) {
    if (samples.isEmpty) {
      return PhaseMetrics(phase: phase);
    }

    final usable = SpectralEegAnalyzer.usableSamples(samples);
    if (usable.isEmpty) {
      return PhaseMetrics(
        phase: phase,
        sampleCount: samples.length,
        dataInsufficient: true,
      );
    }

    final bands = SpectralEegAnalyzer.bandsForSamples(usable);
    if (!bands.hasPower) {
      DateTime? first;
      DateTime? last;
      for (final s in samples) {
        final captured = s['capturedAt'] as String?;
        if (captured != null) {
          final t = DateTime.tryParse(captured);
          if (t != null) {
            first ??= t;
            last = t;
          }
        }
      }
      final duration = (first != null && last != null)
          ? last.difference(first).inSeconds.abs()
          : 0;
      return PhaseMetrics(
        phase: phase,
        sampleCount: samples.length,
        durationSeconds: duration,
        dataInsufficient: true,
      );
    }

    final attnBands = SpectralEegAnalyzer.attentionBandsForSamples(usable);
    var scores = SpectralEegAnalyzer.scoresFromBands(
      bands,
      attentionRaw: attnBands,
    );

    // Baseline-relative skor: görev oranı / baseline oranı → yeniden skorla
    if (baselineBands != null &&
        baselineBands.hasPower &&
        phase != 'baseline') {
      scores = _baselineRelativeScores(bands, baselineBands, attnBands);
    }

    final norm = bands.relative();
    final feat = scores.features;

    DateTime? first;
    DateTime? last;
    for (final s in samples) {
      final captured = s['capturedAt'] as String?;
      if (captured != null) {
        final t = DateTime.tryParse(captured);
        if (t != null) {
          first ??= t;
          last = t;
        }
      }
    }
    final duration = (first != null && last != null)
        ? last.difference(first).inSeconds.abs()
        : 0;

    return PhaseMetrics(
      phase: phase,
      attention: scores.attention,
      focus: scores.focus,
      stress: scores.stress,
      engagement: scores.engagement,
      relaxation: scores.relaxation,
      interest: scores.interest,
      excitement: scores.excitement,
      mentalFatigue: scores.mentalFatigue,
      distraction: scores.distraction,
      alpha: norm.alpha * 100,
      beta: norm.beta * 100,
      theta: norm.theta * 100,
      delta: norm.delta * 100,
      gamma: norm.gamma * 100,
      thetaBeta: feat.thetaBeta,
      alphaBeta: feat.alphaBeta,
      betaAlpha: feat.betaAlpha,
      sampleCount: samples.length,
      durationSeconds: duration,
      dataInsufficient: !scores.sufficientData,
    );
  }

  /// Baseline'a göre göreli özellikler → 0–100 skor.
  ///
  /// task_feature / baseline_feature oranını log-lojistik ile skorlar.
  /// Böylece sonuçlar "absolute değil baseline-relative" olur.
  CognitiveScores _baselineRelativeScores(
    SpectralBands task,
    SpectralBands baseline,
    SpectralBands taskAttention,
  ) {
    final tFeat = SpectralEegAnalyzer.featuresFromBands(task);
    final bFeat = SpectralEegAnalyzer.featuresFromBands(baseline);
    final tAttn = SpectralEegAnalyzer.featuresFromBands(taskAttention);

    double rel(double taskV, double baseV) {
      if (baseV.abs() < 1e-9) return taskV;
      return taskV / baseV;
    }

    // midpoint=1.0 → baseline ile aynı = ~50 skor
    double scoreRel(double taskV, double baseV) =>
        SpectralEegAnalyzer.ratioToScore(
          rel(taskV, baseV).clamp(1e-6, 1e6),
          midpoint: 1.0,
          scale: 0.6,
        );

    final focus = scoreRel(tFeat.focus, bFeat.focus);
    final engagement = scoreRel(tFeat.engagement, bFeat.engagement);
    final mentalFatigue = scoreRel(tFeat.mentalFatigue, bFeat.mentalFatigue);
    final relaxation = scoreRel(tFeat.relaxation, bFeat.relaxation);
    final stress = scoreRel(tFeat.stress, bFeat.stress);
    final distraction = scoreRel(tFeat.distraction, bFeat.distraction);
    final attnTbr = scoreRel(tAttn.attentionTbr, bFeat.attentionTbr);
    final attention = (0.55 * attnTbr + 0.45 * engagement).clamp(1.0, 99.0);
    final excitement = scoreRel(
      tFeat.engagement * 0.5 + task.relative().gamma,
      bFeat.engagement * 0.5 + baseline.relative().gamma,
    );
    final interest = (0.7 * engagement + 0.3 * excitement).clamp(1.0, 99.0);

    return CognitiveScores(
      attention: attention.toDouble(),
      focus: focus,
      engagement: engagement,
      mentalFatigue: mentalFatigue,
      relaxation: relaxation,
      stress: stress,
      distraction: distraction,
      interest: interest.toDouble(),
      excitement: excitement,
      features: tFeat,
      sufficientData: true,
    );
  }

  VideoExperimentStats _videoStats(List<VideoWatchEvent> events) {
    if (events.isEmpty) return VideoExperimentStats.empty;

    final uniqueVideos = <String>{};
    final watchCount = <String, int>{};
    final categorySeconds = <String, int>{};
    var totalSec = 0;

    for (final e in events) {
      uniqueVideos.add(e.videoId);
      watchCount[e.videoId] = (watchCount[e.videoId] ?? 0) + 1;
      totalSec += e.watchDurationSeconds;
      final cat = e.category.isEmpty ? 'Diğer' : e.category;
      categorySeconds[cat] =
          (categorySeconds[cat] ?? 0) + e.watchDurationSeconds;
    }

    final rewatched = watchCount.values.where((c) => c > 1).length;

    return VideoExperimentStats(
      totalVideos: uniqueVideos.length,
      totalScrolls: events.length,
      rewatchedVideos: rewatched,
      averageWatchSeconds: events.isEmpty ? 0 : totalSec / events.length,
      categoryWatchSeconds: categorySeconds,
      totalWatchSeconds: totalSec,
    );
  }

  double _avgNonZero(List<double> values) {
    final filtered = values.where((v) => v > 0).toList();
    if (filtered.isEmpty) return 0;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  /// Gerçek epoch zaman serisi (≈2 sn); tek spike üretmez.
  ({
    List<double> attention,
    List<double> focus,
    List<double> stress,
    List<double> engagement,
  }) _epochSeries(List<Map<String, dynamic>> samples) {
    final epochs = SpectralEegAnalyzer.epochScores(samples, epochSeconds: 2.0);
    if (epochs.isEmpty) {
      return (
        attention: const <double>[],
        focus: const <double>[],
        stress: const <double>[],
        engagement: const <double>[],
      );
    }

    // Çok uzunsa eşit aralıklı örnekle (max 60 nokta)
    const maxPoints = 60;
    if (epochs.length <= maxPoints) {
      return (
        attention: [for (final e in epochs) e.attention],
        focus: [for (final e in epochs) e.focus],
        stress: [for (final e in epochs) e.stress],
        engagement: [for (final e in epochs) e.engagement],
      );
    }

    final step = epochs.length / maxPoints;
    final attention = <double>[];
    final focus = <double>[];
    final stress = <double>[];
    final engagement = <double>[];
    for (var i = 0; i < maxPoints; i++) {
      final idx = (i * step).floor().clamp(0, epochs.length - 1);
      final e = epochs[idx];
      attention.add(e.attention);
      focus.add(e.focus);
      stress.add(e.stress);
      engagement.add(e.engagement);
    }
    return (
      attention: attention,
      focus: focus,
      stress: stress,
      engagement: engagement,
    );
  }
}
