import '../models/experiment_result.dart';
import '../models/phase_metrics.dart';
import '../models/video_experiment_stats.dart';
import '../models/video_watch_event.dart';
import 'eeg_buffer_service.dart';

/// Buffer + watch event'lerden özet sonuç üretir.
class ResultCalculator {
  ExperimentResult calculate({
    required String experimentId,
    required String participantId,
    required EegBufferService buffer,
    List<VideoWatchEvent> watchEvents = const [],
  }) {
    final all = buffer.samples;
    final overall = _metricsFor(all, phase: 'overall');
    final baseline = _metricsFor(
      buffer.samplesForPhase('baseline'),
      phase: 'baseline',
    );
    final reels = _metricsFor(
      buffer.samplesForPhase('reels'),
      phase: 'reels',
    );
    final text = _metricsFor(
      buffer.samplesForPhase('text'),
      phase: 'text',
    );

    final videoStats = _videoStats(watchEvents);

    // Baseline farkı: görev ortalaması − baseline attention
    final taskAttention = _avgNonZero([reels.attention, text.attention]);
    final baselineDiff = taskAttention - baseline.attention;

    // Mental fatigue: theta/alpha oranı + distraction proxy
    final mentalFatigue = ((overall.theta /
                    (overall.alpha <= 0 ? 0.01 : overall.alpha)) *
                40 +
            overall.stress * 0.4)
        .clamp(0, 100)
        .toDouble();

    final series = _downsampleSeries(all);

    return ExperimentResult(
      resultId: '',
      experimentId: experimentId,
      participantId: participantId,
      averageAttention: overall.attention,
      averageFocus: overall.focus,
      averageStress: overall.stress,
      averageRelaxation: overall.relaxation,
      averageInterest: overall.interest,
      averageEngagement: overall.engagement,
      averageExcitement: overall.excitement,
      alphaPower: overall.alpha,
      betaPower: overall.beta,
      thetaPower: overall.theta,
      deltaPower: overall.delta,
      gammaPower: overall.gamma,
      mentalFatigue: mentalFatigue,
      distractionScore: (100 - overall.focus).clamp(0, 100),
      baselineDifference: baselineDiff,
      focusScore: overall.focus,
      baseline: baseline,
      reels: reels,
      text: text,
      videoStats: videoStats,
      attentionSeries: series.attention,
      focusSeries: series.focus,
      stressSeries: series.stress,
      engagementSeries: series.engagement,
      createdAt: DateTime.now(),
    );
  }

  PhaseMetrics _metricsFor(List<Map<String, dynamic>> samples,
      {required String phase}) {
    if (samples.isEmpty) {
      return PhaseMetrics(phase: phase);
    }

    double sumSignal = 0;
    double sumQuality = 0;
    double sumAlpha = 0;
    double sumBeta = 0;
    double sumTheta = 0;
    double sumDelta = 0;
    double sumGamma = 0;
    var bandN = 0;

    DateTime? first;
    DateTime? last;

    for (final s in samples) {
      sumSignal += (s['signal'] as num?)?.toDouble() ?? 0;
      sumQuality += (s['overallQuality'] as num?)?.toDouble() ?? 0;

      final captured = s['capturedAt'] as String?;
      if (captured != null) {
        final t = DateTime.tryParse(captured);
        if (t != null) {
          first ??= t;
          last = t;
        }
      }

      final band = s['bandPower'];
      if (band is Map && band.isNotEmpty) {
        final values = band.values
            .map((v) => (v as num?)?.toDouble() ?? 0.0)
            .toList();
        if (values.isEmpty) continue;
        values.sort();
        final mid = values[values.length ~/ 2];
        // Sensör bandPower'ı proxy: kalite dağılımından frekans bantları
        sumAlpha += mid * 0.9;
        sumBeta += mid * 1.1;
        sumTheta += mid * 0.7;
        sumDelta += mid * 0.5;
        sumGamma += mid * 0.35;
        bandN++;
      }
    }

    final n = samples.length.toDouble();
    final avgSignal = sumSignal / n;
    final avgQuality = sumQuality / n;
    final focus = (avgQuality / 4.0 * 100).clamp(0, 100).toDouble();
    final distraction = (100 - focus).clamp(0, 100).toDouble();
    final engagement =
        ((avgSignal + focus / 100) / 2 * 100).clamp(0, 100).toDouble();
    final stress = (distraction * 0.65).clamp(0, 100).toDouble();
    final relaxation = (100 - stress).clamp(0, 100).toDouble();
    final excitement = (avgSignal * 100).clamp(0, 100).toDouble();
    final interest = (engagement * 0.92).clamp(0, 100).toDouble();
    final attention = ((focus * 0.7) + (engagement * 0.3)).clamp(0, 100);

    final duration = (first != null && last != null)
        ? last.difference(first).inSeconds.abs()
        : 0;

    final div = bandN > 0 ? bandN.toDouble() : 1.0;

    return PhaseMetrics(
      phase: phase,
      attention: attention.toDouble(),
      focus: focus,
      stress: stress,
      engagement: engagement,
      relaxation: relaxation,
      interest: interest,
      excitement: excitement,
      alpha: sumAlpha / div,
      beta: sumBeta / div,
      theta: sumTheta / div,
      delta: sumDelta / div,
      gamma: sumGamma / div,
      sampleCount: samples.length,
      durationSeconds: duration,
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
      averageWatchSeconds:
          events.isEmpty ? 0 : totalSec / events.length,
      categoryWatchSeconds: categorySeconds,
      totalWatchSeconds: totalSec,
    );
  }

  double _avgNonZero(List<double> values) {
    final filtered = values.where((v) => v > 0).toList();
    if (filtered.isEmpty) return 0;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  ({
    List<double> attention,
    List<double> focus,
    List<double> stress,
    List<double> engagement,
  }) _downsampleSeries(List<Map<String, dynamic>> samples) {
    if (samples.isEmpty) {
      return (
        attention: const <double>[],
        focus: const <double>[],
        stress: const <double>[],
        engagement: const <double>[],
      );
    }

    const maxPoints = 60;
    final step = samples.length <= maxPoints
        ? 1
        : (samples.length / maxPoints).ceil();

    final attention = <double>[];
    final focus = <double>[];
    final stress = <double>[];
    final engagement = <double>[];

    for (var i = 0; i < samples.length; i += step) {
      final s = samples[i];
      final q = (s['overallQuality'] as num?)?.toDouble() ?? 0;
      final sig = (s['signal'] as num?)?.toDouble() ?? 0;
      final f = (q / 4.0 * 100).clamp(0, 100).toDouble();
      final eng = ((sig + f / 100) / 2 * 100).clamp(0, 100).toDouble();
      final st = ((100 - f) * 0.65).clamp(0, 100).toDouble();
      final att = ((f * 0.7) + (eng * 0.3)).clamp(0, 100).toDouble();
      attention.add(att);
      focus.add(f);
      stress.add(st);
      engagement.add(eng);
    }

    return (
      attention: attention,
      focus: focus,
      stress: stress,
      engagement: engagement,
    );
  }
}
