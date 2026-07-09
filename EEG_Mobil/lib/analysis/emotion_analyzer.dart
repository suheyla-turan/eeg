import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';

/// Sensör anatomik / işlevsel rollerine göre kural tabanlı duygu skoru.
///
/// Emotiv contact quality (0–4) bölge aktivasyon proxy'si olarak kullanılır.
/// İleride band-power (pow) stream ile değiştirilebilir.
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

  /// Sol frontal → yaklaşma / olumlu duygulanım
  static const _leftFrontal = ['AF3', 'F3', 'F7'];

  /// Sağ frontal → kaçınma / olumsuz duygulanım
  static const _rightFrontal = ['AF4', 'F4', 'F8'];

  /// Prefrontal dikkat / yürütücü işlev
  static const _prefrontal = ['AF3', 'AF4', 'F3', 'F4'];

  /// Sağ temporal + inferior frontal → duygusal uyarılma / öfke
  static const _angerSites = ['F8', 'F4', 'T8', 'FC6'];

  /// Oksipital + parietal → dinlenme / görsel sakinlik
  static const _calmSites = ['O1', 'O2', 'P7', 'P8'];

  /// Frontocentral motor gerilim + frontal arousal → stres
  static const _stressSites = ['AF3', 'AF4', 'FC5', 'FC6', 'F3', 'F4'];

  /// Dil / işitsel (sol temporal) — odak destekleyici
  static const _languageSites = ['T7', 'F7'];

  static EmotionAnalysis analyze(LiveEegState live) {
    final q = <String, double>{};
    for (final entry in live.contactQuality.entries) {
      q[entry.key] = _qualityToUnit(entry.value);
    }

    final left = _avg(q, _leftFrontal);
    final right = _avg(q, _rightFrontal);
    final prefrontal = _avg(q, _prefrontal);
    final anger = _avg(q, _angerSites);
    final calm = _avg(q, _calmSites);
    final stress = _avg(q, _stressSites);
    final language = _avg(q, _languageSites);
    final asymmetry = left - right; // + → mutlu, − → üzgün
    final balance = 1.0 - (asymmetry.abs().clamp(0.0, 1.0));

    final activeCount =
        q.values.where((v) => v > 0.15).length;
    final hasSignal = live.connection == ConnectionStatus.connected &&
        activeCount >= 3;

    // Ham skorlar (0–1) — sensör anlamlarına göre
    final raw = <String, double>{
      // Sol frontal baskınlığı → olumlu duygulanım
      'happy': _clamp01(0.22 + left * 0.55 + asymmetry.clamp(0, 1) * 0.35),
      // Sağ frontal baskınlığı → üzüntü / kaçınma
      'sad': _clamp01(0.18 + right * 0.50 + (-asymmetry).clamp(0, 1) * 0.40),
      // Sağ inferior frontal + temporal duygusal uyarılma
      'angry': _clamp01(0.15 + anger * 0.65 + (-asymmetry).clamp(0, 1) * 0.15),
      // Posterior sakinlik + dengeli frontal
      'calm': _clamp01(0.20 + calm * 0.55 + balance * 0.25 - stress * 0.15),
      // Frontal arousal + motor gerilim
      'stressed':
          _clamp01(0.15 + stress * 0.55 + asymmetry.abs() * 0.25 - calm * 0.20),
      // Prefrontal + dil alanları → odak
      'focused':
          _clamp01(0.18 + prefrontal * 0.55 + language * 0.20 + balance * 0.10),
    };

    if (!hasSignal) {
      for (final key in raw.keys.toList()) {
        raw[key] = 0.12;
      }
      raw['calm'] = 0.28;
    }

    final scores = _toPercentages(raw);
    final emotions = _meta.entries.map((e) {
      return EmotionScore(
        key: e.key,
        label: e.value.label,
        score: scores[e.key] ?? 0,
        color: e.value.color,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final dominant = emotions.first;
    final reasons = _buildReasons(
      dominantKey: dominant.key,
      left: left,
      right: right,
      prefrontal: prefrontal,
      anger: anger,
      calm: calm,
      stress: stress,
      language: language,
      asymmetry: asymmetry,
      hasSignal: hasSignal,
      q: q,
    );

    return EmotionAnalysis(
      emotions: emotions,
      dominant: dominant,
      reasons: reasons,
      hasSignal: hasSignal,
    );
  }

  static double _qualityToUnit(ContactQuality q) {
    switch (q) {
      case ContactQuality.good:
        return 1.0;
      case ContactQuality.fair:
        return 0.65;
      case ContactQuality.poor:
        return 0.30;
      case ContactQuality.none:
        return 0.0;
    }
  }

  static double _avg(Map<String, double> q, List<String> ids) {
    if (ids.isEmpty) return 0;
    var sum = 0.0;
    for (final id in ids) {
      sum += q[id] ?? 0;
    }
    return sum / ids.length;
  }

  static double _clamp01(double v) => v.clamp(0.0, 1.0);

  static Map<String, int> _toPercentages(Map<String, double> raw) {
    final total = raw.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return {for (final k in raw.keys) k: (100 / raw.length).round()};
    }

    final exact = {
      for (final e in raw.entries) e.key: (e.value / total) * 100,
    };

    // En büyüğe kalanı vererek toplamı 100 yap
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

  static List<String> _buildReasons({
    required String dominantKey,
    required double left,
    required double right,
    required double prefrontal,
    required double anger,
    required double calm,
    required double stress,
    required double language,
    required double asymmetry,
    required bool hasSignal,
    required Map<String, double> q,
  }) {
    if (!hasSignal) {
      return [
        'Yeterli sensör teması yok. Headset bağlantısını ve elektrot temasını kontrol et.',
      ];
    }

    String topSensors(List<String> ids) {
      final ranked = [...ids]
        ..sort((a, b) => (q[b] ?? 0).compareTo(q[a] ?? 0));
      return ranked.take(3).join(', ');
    }

    switch (dominantKey) {
      case 'happy':
        return [
          'Sol frontal (AF3, F3, F7) teması sağa göre daha güçlü — olumlu duygulanım / yaklaşma.',
          'Öne çıkan kanallar: ${topSensors(_leftFrontal)}',
          'Frontal asimetri: ${(asymmetry * 100).toStringAsFixed(0)}% sol lehine',
        ];
      case 'sad':
        return [
          'Sağ frontal (AF4, F4, F8) baskın — kaçınma / olumsuz duygulanım ile ilişkilendirilir.',
          'Öne çıkan kanallar: ${topSensors(_rightFrontal)}',
          'Frontal asimetri: ${((-asymmetry) * 100).toStringAsFixed(0)}% sağ lehine',
        ];
      case 'angry':
        return [
          'Sağ inferior frontal ve temporal (F8, T8) yüksek — duygusal uyarılma / öfke izi.',
          'Öne çıkan kanallar: ${topSensors(_angerSites)}',
        ];
      case 'calm':
        return [
          'Oksipital–parietal (O1, O2, P7, P8) dengeli — dinlenme / görsel sakinlik.',
          'Öne çıkan kanallar: ${topSensors(_calmSites)}',
          'Frontal denge skoru: ${( (1 - asymmetry.abs()) * 100).toStringAsFixed(0)}%',
        ];
      case 'stressed':
        return [
          'Frontal + frontocentral (AF, FC) yüksek — arousal / motor gerilim (stres).',
          'Öne çıkan kanallar: ${topSensors(_stressSites)}',
        ];
      case 'focused':
        return [
          'Prefrontal (AF3/AF4, F3/F4) güçlü — dikkat ve yürütücü işlev.',
          'Dil/işitsel destek (T7, F7): ${(language * 100).toStringAsFixed(0)}%',
          'Öne çıkan kanallar: ${topSensors(_prefrontal)}',
        ];
      default:
        return ['Sensör dağılımına göre genel durum hesaplandı.'];
    }
  }
}
