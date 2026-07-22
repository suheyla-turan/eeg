import 'package:flutter/material.dart';

import '../data/mock_eeg.dart';
import '../services/spectral_eeg_analyzer.dart';

/// Canlı "duygu" göstergesi — spektral bant proxy indekslerinden.
///
/// Contact quality KULLANILMAZ. Yalnızca API Welch `bandPower` /
/// `relativeBandPower` üzerinden Pope/Klimesch tarzı oranlar hesaplanır.
///
/// Bu bir klinik tanı aracı değildir; bitirme projesi için açıklanabilir
/// spektral proxy göstergeleridir.
class EmotionAnalysis {
  final List<EmotionScore> emotions;
  final EmotionScore dominant;
  final List<String> reasons;
  final bool hasSignal;

  const EmotionAnalysis({
    required this.emotions,
    required this.dominant,
    required this.reasons,
    required this.hasSignal,
  });
}

class EmotionAnalyzer {
  static const _meta = <String, ({String label, Color color})>{
    'happy': (label: 'Mutlu', color: Color(0xFFE8A838)),
    'sad': (label: 'Üzgün', color: Color(0xFF5B7C99)),
    'angry': (label: 'Sinirli', color: Color(0xFFC44B4B)),
    'calm': (label: 'Sakin', color: Color(0xFF1FA8A0)),
    'stressed': (label: 'Stresli', color: Color(0xFFD4783A)),
    'focused': (label: 'Odaklı', color: Color(0xFF0D7A8C)),
  };

  static EmotionAnalysis analyze(LiveEegState live) {
    final bands = _bandsFromLive(live);
    final hasSignal = live.connection == ConnectionStatus.connected &&
        bands.hasPower;

    if (!hasSignal) {
      final flat = _meta.entries
          .map(
            (e) => EmotionScore(
              key: e.key,
              label: e.value.label,
              score: e.key == 'calm' ? 28 : 14,
              color: e.value.color,
            ),
          )
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return EmotionAnalysis(
        emotions: flat,
        dominant: flat.first,
        reasons: const [
          'Veri yetersiz: gerçek EEG spektral bantları yok. '
          'Headset bağlantısını ve EEG stream lisansını kontrol et.',
        ],
        hasSignal: false,
      );
    }

    final scores = SpectralEegAnalyzer.scoresFromBands(bands);
    final rel = bands.relative();

    // Spektral proxy → duygu etiketleri (açıklanabilir, tanı değil)
    final raw = <String, double>{
      // Yüksek alpha + relaxation → sakin / olumlu dinginlik
      'calm': scores.relaxation / 100.0,
      // Focus + düşük distraction → odaklı
      'focused': scores.focus / 100.0,
      // Stress indeksi
      'stressed': scores.stress / 100.0,
      // Yüksek beta/gamma arousal + düşük alpha → uyarılma / öfke proxy
      'angry': ((rel.beta + rel.gamma) / (rel.alpha + 0.05)).clamp(0, 2) / 2,
      // Engagement + alpha dengesi → mutlu/yaklaşma proxy
      'happy': (scores.engagement / 100.0) * (0.5 + rel.alpha),
      // Yüksek theta/beta (TBR) → üzüntü / kaçınma proxy (ters dikkat)
      'sad': (scores.features.thetaBeta / (scores.features.thetaBeta + 1)),
    };

    final pct = _toPercentages(raw);
    final emotions = _meta.entries.map((e) {
      return EmotionScore(
        key: e.key,
        label: e.value.label,
        score: pct[e.key] ?? 0,
        color: e.value.color,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final dominant = emotions.first;
    final reasons = [
      'α=${(rel.alpha * 100).toStringAsFixed(0)}%  '
          'β=${(rel.beta * 100).toStringAsFixed(0)}%  '
          'θ=${(rel.theta * 100).toStringAsFixed(0)}%',
      'Focus ${scores.focus.toStringAsFixed(0)} · '
          'Relax ${scores.relaxation.toStringAsFixed(0)} · '
          'Stress ${scores.stress.toStringAsFixed(0)}',
      'Kaynak: Welch göreli bant güçleri (contact quality kullanılmaz).',
    ];

    return EmotionAnalysis(
      emotions: emotions,
      dominant: dominant,
      reasons: reasons,
      hasSignal: true,
    );
  }

  static SpectralBands _bandsFromLive(LiveEegState live) {
    final src = live.relativeBandPower.isNotEmpty
        ? live.relativeBandPower
        : live.bandPower;
    if (src.isEmpty) return SpectralBands.zero;
    final b = SpectralBands(
      delta: src['delta'] ?? 0,
      theta: src['theta'] ?? 0,
      alpha: src['alpha'] ?? 0,
      beta: src['beta'] ?? 0,
      gamma: src['gamma'] ?? 0,
    );
    return b.hasPower ? b : SpectralBands.zero;
  }

  static Map<String, int> _toPercentages(Map<String, double> raw) {
    final total = raw.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return {for (final k in raw.keys) k: (100 / raw.length).round()};
    }

    final exact = {
      for (final e in raw.entries) e.key: (e.value / total) * 100,
    };

    final floored = {
      for (final e in exact.entries) e.key: e.value.floor(),
    };
    var remainder = 100 - floored.values.fold(0, (a, b) => a + b);
    final byFrac = exact.entries.toList()
      ..sort((a, b) => (b.value - b.value.floor())
          .compareTo(a.value - a.value.floor()));
    for (final e in byFrac) {
      if (remainder <= 0) break;
      floored[e.key] = (floored[e.key] ?? 0) + 1;
      remainder--;
    }
    return floored;
  }
}
