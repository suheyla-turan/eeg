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

  /// Relative band power × 100 (yüzde pay).
  final double alphaPower;
  final double betaPower;
  final double thetaPower;
  final double deltaPower;
  final double gammaPower;

  final double mentalFatigue;
  final double distractionScore;

  /// Baseline'a göre attention yüzde değişimi (örn. +18.0).
  /// Baseline yoksa [double.nan] — UI "Baseline verisi bulunamadı" gösterir.
  final double baselineDifference;
  final double focusScore;

  /// Spektral oranlar (göreli bantlardan).
  final double thetaBetaRatio;
  final double alphaBetaRatio;
  final double betaAlphaRatio;

  /// Gerçek EEG / spektral veri yetersizse true.
  final bool dataInsufficient;
  final String dataInsufficientReason;

  final PhaseMetrics baseline;
  final PhaseMetrics reels;
  final PhaseMetrics text;

  final VideoExperimentStats videoStats;

  /// Epoch zaman serisi (~2 sn).
  final List<double> attentionSeries;
  final List<double> focusSeries;
  final List<double> stressSeries;
  final List<double> engagementSeries;

  final DateTime createdAt;

  /// 1 = eski kalite proxy; 2 = magic-scale; 3 = bilimsel Welch pipeline.
  final int analysisVersion;

  /// Gemini oturum yorumu (Markdown). Boşsa henüz üretilmemiş.
  final String geminiMarkdown;
  final String geminiModel;
  final DateTime? geminiAnalyzedAt;

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
    this.thetaBetaRatio = 0,
    this.alphaBetaRatio = 0,
    this.betaAlphaRatio = 0,
    this.dataInsufficient = false,
    this.dataInsufficientReason = '',
    this.baseline = PhaseMetrics.empty,
    this.reels = PhaseMetrics.empty,
    this.text = PhaseMetrics.empty,
    this.videoStats = VideoExperimentStats.empty,
    this.attentionSeries = const [],
    this.focusSeries = const [],
    this.stressSeries = const [],
    this.engagementSeries = const [],
    required this.createdAt,
    this.analysisVersion = 1,
    this.geminiMarkdown = '',
    this.geminiModel = '',
    this.geminiAnalyzedAt,
  });

  bool get hasGeminiInterpretation => geminiMarkdown.trim().isNotEmpty;

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
      'baselineDifference':
          baselineDifference.isNaN ? null : baselineDifference,
      'focusScore': focusScore,
      'thetaBetaRatio': thetaBetaRatio,
      'alphaBetaRatio': alphaBetaRatio,
      'betaAlphaRatio': betaAlphaRatio,
      'dataInsufficient': dataInsufficient,
      'dataInsufficientReason': dataInsufficientReason,
      'baseline': baseline.toMap(),
      'reels': reels.toMap(),
      'text': text.toMap(),
      'videoStats': videoStats.toMap(),
      'attentionSeries': attentionSeries,
      'focusSeries': focusSeries,
      'stressSeries': stressSeries,
      'engagementSeries': engagementSeries,
      'createdAt': Timestamp.fromDate(createdAt),
      'analysisVersion': analysisVersion,
      'geminiMarkdown': geminiMarkdown,
      'geminiModel': geminiModel,
      'geminiAnalyzedAt': geminiAnalyzedAt != null
          ? Timestamp.fromDate(geminiAnalyzedAt!)
          : null,
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
      baselineDifference: () {
        final v = map['baselineDifference'];
        if (v == null) return double.nan;
        final d = (v as num).toDouble();
        // Eski kayıtlar: baseline yokken yanlışlıkla 100 yazılmış olabilir.
        final baseMap = asMap(map['baseline']);
        final baseSamples = (baseMap['sampleCount'] as num?)?.toInt() ?? 0;
        if (baseSamples == 0 && d.abs() >= 99.5) return double.nan;
        return d;
      }(),
      focusScore: (map['focusScore'] as num?)?.toDouble() ?? 0,
      thetaBetaRatio: (map['thetaBetaRatio'] as num?)?.toDouble() ?? 0,
      alphaBetaRatio: (map['alphaBetaRatio'] as num?)?.toDouble() ?? 0,
      betaAlphaRatio: (map['betaAlphaRatio'] as num?)?.toDouble() ?? 0,
      dataInsufficient: map['dataInsufficient'] as bool? ?? false,
      dataInsufficientReason:
          map['dataInsufficientReason'] as String? ?? '',
      baseline: PhaseMetrics.fromMap(asMap(map['baseline'])),
      reels: PhaseMetrics.fromMap(asMap(map['reels'])),
      text: PhaseMetrics.fromMap(asMap(map['text'])),
      videoStats: VideoExperimentStats.fromMap(asMap(map['videoStats'])),
      attentionSeries: asDoubles(map['attentionSeries']),
      focusSeries: asDoubles(map['focusSeries']),
      stressSeries: asDoubles(map['stressSeries']),
      engagementSeries: asDoubles(map['engagementSeries']),
      createdAt: _readDate(map['createdAt']),
      analysisVersion: (map['analysisVersion'] as num?)?.toInt() ?? 1,
      geminiMarkdown: map['geminiMarkdown'] as String? ?? '',
      geminiModel: map['geminiModel'] as String? ?? '',
      geminiAnalyzedAt: map['geminiAnalyzedAt'] != null
          ? _readDate(map['geminiAnalyzedAt'])
          : null,
    );
  }

  /// Gerçek baseline aşaması örnekleri var mı?
  bool get hasBaselineData =>
      baseline.sampleCount > 0 &&
      !baseline.dataInsufficient &&
      baseline.attention > 1e-6 &&
      !baselineDifference.isNaN;

  /// Emotiv POW kaynağında delta bandı yoktur; Welch'te 0 ≈ hesaplanamadı.
  /// Diğer bantlar doluyken delta ~0 ise N/A gösterilmelidir.
  bool get isDeltaUnavailable {
    if (deltaPower > 0.05) return false;
    final others = alphaPower + betaPower + thetaPower + gammaPower;
    return others > 1.0;
  }

  ExperimentResult copyWith({
    String? resultId,
    PhaseMetrics? baseline,
    PhaseMetrics? reels,
    PhaseMetrics? text,
    VideoExperimentStats? videoStats,
    int? analysisVersion,
    String? geminiMarkdown,
    String? geminiModel,
    DateTime? geminiAnalyzedAt,
    bool clearGemini = false,
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
      thetaBetaRatio: thetaBetaRatio,
      alphaBetaRatio: alphaBetaRatio,
      betaAlphaRatio: betaAlphaRatio,
      dataInsufficient: dataInsufficient,
      dataInsufficientReason: dataInsufficientReason,
      baseline: baseline ?? this.baseline,
      reels: reels ?? this.reels,
      text: text ?? this.text,
      videoStats: videoStats ?? this.videoStats,
      attentionSeries: attentionSeries,
      focusSeries: focusSeries,
      stressSeries: stressSeries,
      engagementSeries: engagementSeries,
      createdAt: createdAt,
      analysisVersion: analysisVersion ?? this.analysisVersion,
      geminiMarkdown: clearGemini ? '' : (geminiMarkdown ?? this.geminiMarkdown),
      geminiModel: clearGemini ? '' : (geminiModel ?? this.geminiModel),
      geminiAnalyzedAt:
          clearGemini ? null : (geminiAnalyzedAt ?? this.geminiAnalyzedAt),
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
