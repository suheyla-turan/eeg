import 'package:cloud_firestore/cloud_firestore.dart';

import 'phase_metrics.dart';
import 'video_experiment_stats.dart';

/// Deney sonucu — genel + aşama bazlı metrikler.
class ExperimentResult {
  final String resultId;
  final String experimentId;
  final String participantId;

  final double averageAttention;
  final double averageFocus;
  final double averageStress;
  final double averageRelaxation;
  final double averageInterest;
  final double averageEngagement;
  final double averageExcitement;

  final double alphaPower;
  final double betaPower;
  final double thetaPower;
  final double deltaPower;
  final double gammaPower;

  final double mentalFatigue;
  final double distractionScore;
  final double baselineDifference;
  final double focusScore;

  final PhaseMetrics baseline;
  final PhaseMetrics reels;
  final PhaseMetrics text;

  final VideoExperimentStats videoStats;

  /// Grafik için zaman serisi (attention örnekleri).
  final List<double> attentionSeries;
  final List<double> focusSeries;
  final List<double> stressSeries;
  final List<double> engagementSeries;

  final DateTime createdAt;

  const ExperimentResult({
    required this.resultId,
    required this.experimentId,
    required this.participantId,
    required this.averageAttention,
    required this.averageFocus,
    required this.averageStress,
    required this.averageRelaxation,
    required this.averageInterest,
    required this.averageEngagement,
    required this.averageExcitement,
    required this.alphaPower,
    required this.betaPower,
    required this.thetaPower,
    required this.deltaPower,
    required this.gammaPower,
    required this.mentalFatigue,
    required this.distractionScore,
    required this.baselineDifference,
    required this.focusScore,
    this.baseline = PhaseMetrics.empty,
    this.reels = PhaseMetrics.empty,
    this.text = PhaseMetrics.empty,
    this.videoStats = VideoExperimentStats.empty,
    this.attentionSeries = const [],
    this.focusSeries = const [],
    this.stressSeries = const [],
    this.engagementSeries = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'resultId': resultId,
      'experimentId': experimentId,
      'participantId': participantId,
      'averageAttention': averageAttention,
      'averageFocus': averageFocus,
      'averageStress': averageStress,
      'averageRelaxation': averageRelaxation,
      'averageInterest': averageInterest,
      'averageEngagement': averageEngagement,
      'averageExcitement': averageExcitement,
      'alphaPower': alphaPower,
      'betaPower': betaPower,
      'thetaPower': thetaPower,
      'deltaPower': deltaPower,
      'gammaPower': gammaPower,
      'mentalFatigue': mentalFatigue,
      'distractionScore': distractionScore,
      'baselineDifference': baselineDifference,
      'focusScore': focusScore,
      'baseline': baseline.toMap(),
      'reels': reels.toMap(),
      'text': text.toMap(),
      'videoStats': videoStats.toMap(),
      'attentionSeries': attentionSeries,
      'focusSeries': focusSeries,
      'stressSeries': stressSeries,
      'engagementSeries': engagementSeries,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExperimentResult.fromMap(Map<String, dynamic> map, {String? id}) {
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map<String, dynamic> ? v : <String, dynamic>{};

    List<double> asDoubles(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    }

    return ExperimentResult(
      resultId: id ?? map['resultId'] as String? ?? '',
      experimentId: map['experimentId'] as String? ?? '',
      participantId: map['participantId'] as String? ?? '',
      averageAttention: (map['averageAttention'] as num?)?.toDouble() ?? 0,
      averageFocus: (map['averageFocus'] as num?)?.toDouble() ?? 0,
      averageStress: (map['averageStress'] as num?)?.toDouble() ?? 0,
      averageRelaxation: (map['averageRelaxation'] as num?)?.toDouble() ?? 0,
      averageInterest: (map['averageInterest'] as num?)?.toDouble() ?? 0,
      averageEngagement: (map['averageEngagement'] as num?)?.toDouble() ?? 0,
      averageExcitement: (map['averageExcitement'] as num?)?.toDouble() ?? 0,
      alphaPower: (map['alphaPower'] as num?)?.toDouble() ?? 0,
      betaPower: (map['betaPower'] as num?)?.toDouble() ?? 0,
      thetaPower: (map['thetaPower'] as num?)?.toDouble() ?? 0,
      deltaPower: (map['deltaPower'] as num?)?.toDouble() ?? 0,
      gammaPower: (map['gammaPower'] as num?)?.toDouble() ?? 0,
      mentalFatigue: (map['mentalFatigue'] as num?)?.toDouble() ?? 0,
      distractionScore: (map['distractionScore'] as num?)?.toDouble() ?? 0,
      baselineDifference: (map['baselineDifference'] as num?)?.toDouble() ?? 0,
      focusScore: (map['focusScore'] as num?)?.toDouble() ?? 0,
      baseline: PhaseMetrics.fromMap(asMap(map['baseline'])),
      reels: PhaseMetrics.fromMap(asMap(map['reels'])),
      text: PhaseMetrics.fromMap(asMap(map['text'])),
      videoStats: VideoExperimentStats.fromMap(asMap(map['videoStats'])),
      attentionSeries: asDoubles(map['attentionSeries']),
      focusSeries: asDoubles(map['focusSeries']),
      stressSeries: asDoubles(map['stressSeries']),
      engagementSeries: asDoubles(map['engagementSeries']),
      createdAt: _readDate(map['createdAt']),
    );
  }

  ExperimentResult copyWith({
    String? resultId,
    PhaseMetrics? baseline,
    PhaseMetrics? reels,
    PhaseMetrics? text,
    VideoExperimentStats? videoStats,
  }) {
    return ExperimentResult(
      resultId: resultId ?? this.resultId,
      experimentId: experimentId,
      participantId: participantId,
      averageAttention: averageAttention,
      averageFocus: averageFocus,
      averageStress: averageStress,
      averageRelaxation: averageRelaxation,
      averageInterest: averageInterest,
      averageEngagement: averageEngagement,
      averageExcitement: averageExcitement,
      alphaPower: alphaPower,
      betaPower: betaPower,
      thetaPower: thetaPower,
      deltaPower: deltaPower,
      gammaPower: gammaPower,
      mentalFatigue: mentalFatigue,
      distractionScore: distractionScore,
      baselineDifference: baselineDifference,
      focusScore: focusScore,
      baseline: baseline ?? this.baseline,
      reels: reels ?? this.reels,
      text: text ?? this.text,
      videoStats: videoStats ?? this.videoStats,
      attentionSeries: attentionSeries,
      focusSeries: focusSeries,
      stressSeries: stressSeries,
      engagementSeries: engagementSeries,
      createdAt: createdAt,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
