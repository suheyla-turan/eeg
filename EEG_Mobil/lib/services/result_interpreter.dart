import '../models/experiment_result.dart';
import '../models/phase_metrics.dart';

/// Tek deney oturumuna ait kısa, tarafsız EEG yorumu.
class ExperimentInterpretation {
  final String reelsAnalysis;
  final String textAnalysis;
  final String comparison;
  final String generalConclusion;
  final List<String> sessionSummary;
  final bool dataLimited;

  const ExperimentInterpretation({
    required this.reelsAnalysis,
    required this.textAnalysis,
    required this.comparison,
    required this.generalConclusion,
    required this.sessionSummary,
    this.dataLimited = false,
  });
}

/// [ExperimentResult] metriklerinden kısa akademik yorum üretir.
class ResultInterpreter {
  const ResultInterpreter._();

  static const double _softThreshold = 4.0;
  static const double _ratioSoftThreshold = 0.06;

  static ExperimentInterpretation interpret(ExperimentResult result) {
    if (result.dataInsufficient ||
        (result.reels.dataInsufficient && result.text.dataInsufficient) ||
        (result.reels.sampleCount == 0 && result.text.sampleCount == 0)) {
      return const ExperimentInterpretation(
        reelsAnalysis:
            'Reels aşamasında yeterli EEG verisi yok; göstergeler yorumlanamadı.',
        textAnalysis:
            'Metin aşamasında yeterli EEG verisi yok; göstergeler yorumlanamadı.',
        comparison:
            'Her iki aşamada da yeterli örnek olmadığı için karşılaştırma yapılamadı.',
        generalConclusion:
            'Bu oturumda karşılaştırmalı değerlendirme üretilemedi. '
            'Bulgular klinik tanı amacı taşımaz.',
        sessionSummary: [
          'Yeterli spektral EEG verisi elde edilemedi.',
          'Bulgular yalnızca bu oturuma aittir; klinik tanı amacı taşımaz.',
        ],
        dataLimited: true,
      );
    }

    final reels = result.reels;
    final text = result.text;

    return ExperimentInterpretation(
      reelsAnalysis: _phaseAnalysis(
        phaseLabel: 'Reels',
        m: reels,
      ),
      textAnalysis: _phaseAnalysis(
        phaseLabel: 'Metin okuma',
        m: text,
      ),
      comparison: _comparison(reels, text),
      generalConclusion: _generalConclusion(reels, text),
      sessionSummary: _sessionSummary(reels, text),
      dataLimited: reels.dataInsufficient ||
          text.dataInsufficient ||
          reels.sampleCount == 0 ||
          text.sampleCount == 0,
    );
  }

  static String _phaseAnalysis({
    required String phaseLabel,
    required PhaseMetrics m,
  }) {
    if (m.dataInsufficient || m.sampleCount == 0) {
      return '$phaseLabel aşamasında yeterli EEG örneği yok.';
    }

    final attn = _pairShort(
      a: m.attention,
      b: m.mentalFatigue,
      aName: 'Attention',
      bName: 'Mental Fatigue',
    );
    final focus = _pairShort(
      a: m.focus,
      b: m.engagement,
      aName: 'Focus',
      bName: 'Engagement',
    );
    final affect = _pairShort(
      a: m.stress,
      b: m.relaxation,
      aName: 'Stres',
      bName: 'Rahatlama',
    );

    return '$phaseLabel: Theta/Beta ${_ratioBand(m.thetaBeta)}, '
        'Alpha/Beta ${_ratioBand(m.alphaBeta)}. '
        '$attn; $focus; $affect.';
  }

  static String _comparison(PhaseMetrics reels, PhaseMetrics text) {
    if (reels.sampleCount == 0 || text.sampleCount == 0) {
      return 'Karşılaştırma için her iki aşamada da yeterli örnek yok.';
    }

    final att = _trend(text.attention - reels.attention);
    final focus = _trend(text.focus - reels.focus);
    final fatigue = _trend(text.mentalFatigue - reels.mentalFatigue);
    final stress = _trend(text.stress - reels.stress);
    final magnitude = _overallMagnitude([
      text.attention - reels.attention,
      text.focus - reels.focus,
      text.mentalFatigue - reels.mentalFatigue,
      text.engagement - reels.engagement,
    ]);

    return 'Reels–metin: $magnitude '
        'Attention $att, Focus $focus, Mental Fatigue $fatigue, '
        'Stres $stress (metne göre).';
  }

  static String _generalConclusion(PhaseMetrics reels, PhaseMetrics text) {
    if (reels.sampleCount == 0 || text.sampleCount == 0) {
      return 'Karşılaştırmalı genel sonuç için yeterli aşama verisi yok. '
          'Bulgular klinik tanı amacı taşımaz.';
    }

    final attD = text.attention - reels.attention;
    final fatD = text.mentalFatigue - reels.mentalFatigue;
    final engD = text.engagement - reels.engagement;
    final tbD = text.thetaBeta - reels.thetaBeta;

    final parts = <String>[
      'İki görev arasında sınırlı bilişsel farklar gözlendi.',
    ];

    if (attD <= -_softThreshold || engD <= -_softThreshold) {
      parts.add('Dikkat/engagement Reels’te görece daha yüksek.');
    } else if (attD >= _softThreshold || engD >= _softThreshold) {
      parts.add('Dikkat/engagement metin aşamasında görece daha yüksek.');
    } else {
      parts.add('Dikkat ve engagement benzer düzeyde.');
    }

    if (fatD >= _softThreshold || tbD >= _ratioSoftThreshold) {
      parts.add('Mental Fatigue / Theta-Beta metinde artış eğiliminde.');
    } else if (fatD <= -_softThreshold || tbD <= -_ratioSoftThreshold) {
      parts.add('Mental Fatigue / Theta-Beta Reels’te görece daha yüksek.');
    } else {
      parts.add('Yorgunluk göstergeleri iki görevde sınırlı değişim gösterdi.');
    }

    parts.add('Tek oturum bulgusudur; klinik tanı amacı taşımaz.');
    return parts.join(' ');
  }

  static List<String> _sessionSummary(PhaseMetrics reels, PhaseMetrics text) {
    if (reels.sampleCount == 0 || text.sampleCount == 0) {
      return const [
        'Karşılaştırma için yeterli aşama verisi yok.',
        'Bulgular yalnızca bu oturuma aittir; klinik tanı amacı taşımaz.',
      ];
    }

    final attD = text.attention - reels.attention;
    final fatD = text.mentalFatigue - reels.mentalFatigue;
    final engD = text.engagement - reels.engagement;
    final tbD = text.thetaBeta - reels.thetaBeta;

    final items = <String>[];

    if (attD <= -_softThreshold) {
      items.add('Dikkat göstergesi Reels’te görece daha yüksek.');
    } else if (attD >= _softThreshold) {
      items.add('Dikkat göstergesi metin aşamasında görece daha yüksek.');
    } else {
      items.add('Dikkat göstergeleri iki görevde benzer.');
    }

    if (fatD >= _softThreshold || tbD >= _ratioSoftThreshold) {
      items.add('Mental Fatigue / Theta-Beta metinde artış eğiliminde.');
    } else if (fatD <= -_softThreshold || tbD <= -_ratioSoftThreshold) {
      items.add('Mental Fatigue / Theta-Beta Reels’te görece daha yüksek.');
    } else {
      items.add('Yorgunluk göstergelerinde sınırlı değişim.');
    }

    if (engD.abs() < _softThreshold) {
      items.add('Engagement iki görevde benzer.');
    } else if (engD < 0) {
      items.add('Engagement Reels’te görece daha yüksek.');
    } else {
      items.add('Engagement metin aşamasında görece daha yüksek.');
    }

    items.add('Bulgular yalnızca bu oturuma aittir; klinik tanı amacı taşımaz.');
    return items;
  }

  static String _trend(double delta, {double threshold = _softThreshold}) {
    if (delta.abs() < threshold) return 'sınırlı';
    if (delta > 0) return 'hafif ↑';
    return 'hafif ↓';
  }

  static String _overallMagnitude(List<double> deltas) {
    final maxAbs = deltas.fold<double>(0, (m, d) => d.abs() > m ? d.abs() : m);
    if (maxAbs < _softThreshold) return 'yalnızca sınırlı fark.';
    if (maxAbs < _softThreshold * 2.5) return 'küçük farklar.';
    return 'orta düzey fark eğilimi.';
  }

  static String _ratioBand(double ratio) {
    if (ratio < 0.45) return 'düşük';
    if (ratio < 0.85) return 'orta-düşük';
    if (ratio < 1.3) return 'orta';
    if (ratio < 2.0) return 'orta-yüksek';
    return 'yüksek';
  }

  static String _pairShort({
    required double a,
    required double b,
    required String aName,
    required String bName,
  }) {
    if (a >= b + _softThreshold) return '$aName > $bName';
    if (b >= a + _softThreshold) return '$bName > $aName';
    return '$aName ≈ $bName';
  }
}
