import 'dart:math' as math;

/// Bilimsel EEG spektral analiz katmanı.
///
/// Pipeline:
///   Ham / API band power → Quality Gate → Relative bands → Feature ratios
///   → (isteğe bağlı) Baseline normalizasyonu → 0–100 skor
///
/// ÖNEMLİ: Emotiv DEV stream (contact quality, signal, battery) bu katmana
/// GİRMEZ. Yalnızca örnek kabul/red için [overallQuality] kullanılır.
///
/// Bant tanımları (Klimesch, 1999; standart klinik EEG):
///   δ 0.5–4 · θ 4–8 · α 8–13 · β 13–30 · γ 30–45 Hz
class SpectralBands {
  const SpectralBands({
    this.delta = 0,
    this.theta = 0,
    this.alpha = 0,
    this.beta = 0,
    this.gamma = 0,
  });

  final double delta;
  final double theta;
  final double alpha;
  final double beta;
  final double gamma;

  static const zero = SpectralBands();

  double get total => delta + theta + alpha + beta + gamma;

  bool get hasPower => total > 1e-12;

  /// Relative band power (P_band / Σ P).
  SpectralBands relative() {
    final t = total;
    if (t <= 1e-12) return zero;
    return SpectralBands(
      delta: delta / t,
      theta: theta / t,
      alpha: alpha / t,
      beta: beta / t,
      gamma: gamma / t,
    );
  }

  /// Log-power (doğal log); oran kararlılığı için.
  SpectralBands logPower() {
    double lp(double v) => math.log(math.max(v, 1e-18));
    return SpectralBands(
      delta: lp(delta),
      theta: lp(theta),
      alpha: lp(alpha),
      beta: lp(beta),
      gamma: lp(gamma),
    );
  }

  /// Geriye uyumluluk.
  SpectralBands normalized() => relative();
}

/// Bölgesel kanal grupları (Emotiv EPOC 10–20).
class ChannelRegions {
  static const frontal = ['AF3', 'F7', 'F3', 'FC5', 'FC6', 'F4', 'F8', 'AF4'];

  /// Dikkat / yürütücü işlev — prefrontal odak (AF3/F3/F4/AF4).
  /// Gevins & Smith (2000); frontal midline theta/beta çalışmaları.
  static const attentionFrontal = ['AF3', 'F3', 'F4', 'AF4'];

  static const temporal = ['T7', 'T8'];
  static const parietal = ['P7', 'P8'];
  static const occipital = ['O1', 'O2'];

  static const all = [
    'AF3', 'F7', 'F3', 'FC5', 'T7', 'P7', 'O1', 'O2',
    'P8', 'T8', 'FC6', 'F4', 'F8', 'AF4',
  ];
}

/// Ham spektral oranlar (normalize edilmemiş, açıklanabilir).
class SpectralFeatures {
  const SpectralFeatures({
    required this.focus,
    required this.engagement,
    required this.attentionTbr,
    required this.mentalFatigue,
    required this.relaxation,
    required this.stress,
    required this.distraction,
    required this.thetaBeta,
    required this.alphaBeta,
    required this.betaAlpha,
  });

  /// Focus = β / (θ + α)
  /// Pope et al. (1995) engagement/focus indeksinin odak bileşeni.
  final double focus;

  /// Engagement = (β + γ) / θ
  /// Pope et al. (1995) engagement index genişletmesi (γ dahil).
  final double engagement;

  /// Attention proxy = β / θ  (TBR'nin tersi)
  /// Lubar (1991); Barry et al. — düşük theta/beta → daha iyi dikkat.
  final double attentionTbr;

  /// Mental Fatigue = θ / α
  /// Jap et al. (2009); Mekonnen et al. — yorgunlukta θ↑ α↓.
  final double mentalFatigue;

  /// Relaxation = α / (α + β)
  /// Klimesch (1999) — artmış göreli alpha → dinlenme.
  final double relaxation;

  /// Stress = β / α
  /// Seo & Lee (2010); yüksek beta + düşük alpha → arousal/stres.
  final double stress;

  /// Distraction = (θ + α_slow-proxy) / (β + ε)  ≈ (θ) / (β + γ)
  /// Bağımsız gösterge: yüksek theta + düşük beta/gamma (odalak kaybı).
  /// 100−Focus TÜRETİLMEZ.
  final double distraction;

  final double thetaBeta;
  final double alphaBeta;
  final double betaAlpha;

  static const zero = SpectralFeatures(
    focus: 0,
    engagement: 0,
    attentionTbr: 0,
    mentalFatigue: 0,
    relaxation: 0,
    stress: 0,
    distraction: 0,
    thetaBeta: 0,
    alphaBeta: 0,
    betaAlpha: 0,
  );
}

/// 0–100 bilişsel skorlar + bant özeti.
class CognitiveScores {
  const CognitiveScores({
    required this.attention,
    required this.focus,
    required this.engagement,
    required this.mentalFatigue,
    required this.relaxation,
    required this.stress,
    required this.distraction,
    required this.interest,
    required this.excitement,
    required this.features,
    this.sufficientData = true,
  });

  final double attention;
  final double focus;
  final double engagement;
  final double mentalFatigue;
  final double relaxation;
  final double stress;
  final double distraction;
  final double interest;
  final double excitement;
  final SpectralFeatures features;
  final bool sufficientData;

  static const insufficient = CognitiveScores(
    attention: 0,
    focus: 0,
    engagement: 0,
    mentalFatigue: 0,
    relaxation: 0,
    stress: 0,
    distraction: 0,
    interest: 0,
    excitement: 0,
    features: SpectralFeatures.zero,
    sufficientData: false,
  );
}

class SpectralEegAnalyzer {
  /// Emotiv overall contact quality 0–4; yalnızca örnek kabul/red.
  static const minOverallQuality = 2;

  static bool isSpectralBandMap(Map<dynamic, dynamic> band) {
    return band.containsKey('alpha') ||
        band.containsKey('beta') ||
        band.containsKey('theta');
  }

  /// Band map'ten SpectralBands oku (boş/sıfır → null).
  static SpectralBands? _readBands(dynamic raw) {
    if (raw is! Map) return null;
    if (!isSpectralBandMap(raw)) return null;
    final b = SpectralBands(
      delta: (raw['delta'] as num?)?.toDouble() ?? 0,
      theta: (raw['theta'] as num?)?.toDouble() ?? 0,
      alpha: (raw['alpha'] as num?)?.toDouble() ?? 0,
      beta: (raw['beta'] as num?)?.toDouble() ?? 0,
      gamma: (raw['gamma'] as num?)?.toDouble() ?? 0,
    );
    return b.hasPower ? b : null;
  }

  /// Örnekte gerçek spektral bant var mı? (CQ sahte EEG değil)
  static bool sampleHasSpectralData(Map<String, dynamic> sample) {
    return _bandsFromSample(sample) != null;
  }

  static SpectralBands? _bandsFromSample(Map<String, dynamic> sample) {
    return _readBands(sample['relativeBandPower']) ??
        _readBands(sample['relative_band_power']) ??
        _readBands(sample['bandPower']) ??
        _readBands(sample['band_power']);
  }

  /// Etkin kalite: overall > 0 ise o; değilse contactQuality medyanı.
  static int effectiveQuality(Map<String, dynamic> sample) {
    final overall = (sample['overallQuality'] as num?)?.toInt() ??
        (sample['overall_quality'] as num?)?.toInt() ??
        0;
    if (overall > 0) return overall;

    final cq = sample['contactQuality'] ?? sample['contact_quality'];
    if (cq is! Map || cq.isEmpty) return 0;
    final vals = <int>[];
    for (final v in cq.values) {
      if (v is num) vals.add(v.toInt());
    }
    if (vals.isEmpty) return 0;
    vals.sort();
    return vals[vals.length ~/ 2];
  }

  static List<Map<String, dynamic>> qualityFilter(
    List<Map<String, dynamic>> samples,
  ) {
    return samples.where((s) {
      if (sampleHasSpectralData(s)) return true;
      final q = effectiveQuality(s);
      if (q >= 40) return true;
      return q >= minOverallQuality;
    }).toList();
  }

  static List<Map<String, dynamic>> usableSamples(
    List<Map<String, dynamic>> samples,
  ) {
    if (samples.isEmpty) return const [];
    final filtered = qualityFilter(samples);
    if (filtered.isNotEmpty) return filtered;
    final spectral = samples.where(sampleHasSpectralData).toList();
    if (spectral.isNotEmpty) return spectral;
    return const [];
  }

  /// Neden spektral analiz yapılamadı? (UI)
  static String insufficientReason(List<Map<String, dynamic>> samples) {
    if (samples.isEmpty) return 'Kayıtta EEG örneği yok.';
    if (samples.where(sampleHasSpectralData).isNotEmpty) {
      return 'Spektral bantlar var ama kalite/artefakt eledi.';
    }
    if (_looksLikeRealEeg(samples)) {
      return 'Ham EEG var ancak spektral bant üretilemedi.';
    }
    if (_looksLikeContactQualityEeg(samples)) {
      return 'Kayıtta yalnızca contact quality var; ham EEG stream yok. '
          'Emotiv EEG lisansını kontrol edip deneyi tekrarlayın.';
    }
    return 'Gerçek EEG spektral bantları yok. Deneyde EEG stream (eeg) '
        'aktif olmalı; yalnızca DEV (cihaz durumu) yeterli değil.';
  }

  /// Öncelik: spektral bandPower (tüm örnekler) → gerçek µV serisi.
  static SpectralBands bandsForSamples(List<Map<String, dynamic>> samples) {
    if (samples.isEmpty) return SpectralBands.zero;

    final withSpectral = samples.where(sampleHasSpectralData).toList();
    if (withSpectral.isNotEmpty) {
      return _averageSpectral(withSpectral);
    }

    final usable = usableSamples(samples);
    final pool = usable.isNotEmpty ? usable : samples;
    return _fromEegSeries(pool);
  }

  static SpectralBands _averageSpectral(List<Map<String, dynamic>> samples) {
    var n = 0;
    var sumD = 0.0, sumT = 0.0, sumA = 0.0, sumB = 0.0, sumG = 0.0;
    for (final s in samples) {
      final band = _bandsFromSample(s);
      if (band == null) continue;
      sumD += band.delta;
      sumT += band.theta;
      sumA += band.alpha;
      sumB += band.beta;
      sumG += band.gamma;
      n++;
    }
    if (n == 0) return SpectralBands.zero;
    final nn = n.toDouble();
    return SpectralBands(
      delta: sumD / nn,
      theta: sumT / nn,
      alpha: sumA / nn,
      beta: sumB / nn,
      gamma: sumG / nn,
    );
  }

  static SpectralBands attentionBandsForSamples(
    List<Map<String, dynamic>> samples,
  ) {
    if (samples.isEmpty) return SpectralBands.zero;

    final pool = samples.where(sampleHasSpectralData).toList();
    final use = pool.isNotEmpty ? pool : usableSamples(samples);

    var n = 0;
    var sumD = 0.0, sumT = 0.0, sumA = 0.0, sumB = 0.0, sumG = 0.0;
    for (final s in use) {
      final regions = s['regionBandPower'] ?? s['region_band_power'];
      Map? frontal;
      if (regions is Map) {
        frontal = regions['attention_frontal'] as Map? ??
            regions['frontal'] as Map?;
      }
      final band = _readBands(frontal) ?? _bandsFromSample(s);
      if (band == null) continue;
      sumD += band.delta;
      sumT += band.theta;
      sumA += band.alpha;
      sumB += band.beta;
      sumG += band.gamma;
      n++;
    }

    if (n == 0) return bandsForSamples(samples);
    final nn = n.toDouble();
    return SpectralBands(
      delta: sumD / nn,
      theta: sumT / nn,
      alpha: sumA / nn,
      beta: sumB / nn,
      gamma: sumG / nn,
    );
  }

  /// Göreli bantlardan spektral özellikler (formüller sabit, çarpan yok).
  static SpectralFeatures featuresFromBands(SpectralBands raw) {
    final b = raw.relative();
    if (!b.hasPower) return SpectralFeatures.zero;
    const eps = 1e-6;

    final focus = b.beta / (b.theta + b.alpha + eps);
    final engagement = (b.beta + b.gamma) / (b.theta + eps);
    final attentionTbr = b.beta / (b.theta + eps);
    final mentalFatigue = b.theta / (b.alpha + eps);
    final relaxation = b.alpha / (b.alpha + b.beta + eps);
    final stress = b.beta / (b.alpha + eps);
    // Bağımsız distraction: theta baskınlığı / hızlı aktivite
    final distraction = b.theta / (b.beta + b.gamma + eps);
    final thetaBeta = b.theta / (b.beta + eps);
    final alphaBeta = b.alpha / (b.beta + eps);
    final betaAlpha = b.beta / (b.alpha + eps);

    return SpectralFeatures(
      focus: focus,
      engagement: engagement,
      attentionTbr: attentionTbr,
      mentalFatigue: mentalFatigue,
      relaxation: relaxation,
      stress: stress,
      distraction: distraction,
      thetaBeta: thetaBeta,
      alphaBeta: alphaBeta,
      betaAlpha: betaAlpha,
    );
  }

  /// Oranı 0–100 skora çevirir.
  ///
  /// Log-uzayda lojistik: score = 100 / (1 + exp(−(ln(r) − ln(mid)) / s))
  /// [midpoint]: literatürde dinlenme/orta tipik oran değeri (belgelenir).
  /// [scale]: log-uzayda yumuşaklık; küçük → daha dik.
  /// Clamp yalnızca en sonda, lojistik zaten (0,100) aralığındadır.
  static double ratioToScore(
    double ratio, {
    required double midpoint,
    double scale = 0.85,
  }) {
    if (ratio <= 0 || !ratio.isFinite) return 0;
    final x = math.log(ratio);
    final m = math.log(midpoint);
    final z = (x - m) / scale;
    // Soft saturation — sürekli 0 veya 100 üretmez
    return (100.0 / (1.0 + math.exp(-z))).clamp(1.0, 99.0);
  }

  /// Baseline'a göre yüzde değişim: 100 * (task − base) / base.
  ///
  /// Baseline yoksa [double.nan] döner — UI "Baseline verisi bulunamadı"
  /// göstermelidir. Baseline=0 iken sahte +100 üretilmez.
  static double percentChange(double task, double baseline) {
    if (baseline.abs() < 1e-9) {
      return double.nan;
    }
    return 100.0 * (task - baseline) / baseline.abs();
  }

  /// Bantlardan bilişsel skorlar.
  /// DEV signal / contact quality parametresi YOKTUR.
  static CognitiveScores scoresFromBands(
    SpectralBands raw, {
    SpectralBands? attentionRaw,
  }) {
    if (!raw.hasPower) return CognitiveScores.insufficient;

    final global = featuresFromBands(raw);
    final attnBands = attentionRaw ?? raw;
    final attnFeat = featuresFromBands(attnBands);

    // Literatür orta noktaları (göreli bant oranları için tipik dinlenme)
    // Pope 1995; Lubar 1991; Jap 2009; Seo & Lee 2010
    final focus = ratioToScore(global.focus, midpoint: 0.55);
    final engagement = ratioToScore(global.engagement, midpoint: 1.2);
    final mentalFatigue = ratioToScore(global.mentalFatigue, midpoint: 1.0);
    final relaxation = ratioToScore(global.relaxation, midpoint: 0.55);
    final stress = ratioToScore(global.stress, midpoint: 1.0);
    final distraction = ratioToScore(global.distraction, midpoint: 0.8);

    // Attention: prefrontal β/θ (TBR inverse) + engagement
    // Lubar (1991) + Pope (1995) kombinasyonu — ağırlıklar açıklanabilir.
    final attnFromTbr = ratioToScore(attnFeat.attentionTbr, midpoint: 1.0);
    final attention = (0.55 * attnFromTbr + 0.45 * engagement).clamp(1.0, 99.0);

    // Interest / Excitement: spektral uyarılma (γ + engagement) — CQ yok
    final excitement = ratioToScore(
      (raw.relative().gamma + global.engagement * 0.15).clamp(1e-6, 10),
      midpoint: 0.25,
    );
    final interest =
        (0.7 * engagement + 0.3 * excitement).clamp(1.0, 99.0);

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
      features: global,
      sufficientData: true,
    );
  }

  /// Epoch bazlı skor serisi (≈ [epochSeconds] sn pencereler).
  static List<CognitiveScores> epochScores(
    List<Map<String, dynamic>> samples, {
    double epochSeconds = 2.0,
  }) {
    if (samples.isEmpty) return const [];

    final usable = usableSamples(samples);
    if (usable.isEmpty) return const [];

    // Örnekleri zamana göre epoch'lara böl
    final epochs = <List<Map<String, dynamic>>>[];
    List<Map<String, dynamic>> current = [];
    DateTime? epochStart;

    for (final s in usable) {
      final t = _parseTime(s);
      if (t == null) {
        current.add(s);
        continue;
      }
      epochStart ??= t;
      if (t.difference(epochStart).inMilliseconds / 1000.0 >= epochSeconds &&
          current.isNotEmpty) {
        epochs.add(current);
        current = [s];
        epochStart = t;
      } else {
        current.add(s);
      }
    }
    if (current.isNotEmpty) epochs.add(current);

    // Zaman damgası yoksa sabit boyutta dilimle (~2 sn @ 2 Hz → 4 örnek)
    if (epochs.length <= 1 && usable.length >= 4) {
      epochs.clear();
      final chunk = math.max(2, (epochSeconds * 2).round());
      for (var i = 0; i < usable.length; i += chunk) {
        final end = math.min(i + chunk, usable.length);
        epochs.add(usable.sublist(i, end));
      }
    }

    final out = <CognitiveScores>[];
    for (final ep in epochs) {
      final bands = bandsForSamples(ep);
      if (!bands.hasPower) continue;
      final attn = attentionBandsForSamples(ep);
      out.add(scoresFromBands(bands, attentionRaw: attn));
    }
    return out;
  }

  // ─── Dahili: kanal zaman serisinden bant ─────────────────────────────

  /// Gerçek µV EEG mi, yoksa CQ (0–4) sahte sinyal mi?
  static bool _looksLikeContactQualityEeg(
    List<Map<String, dynamic>> samples,
  ) {
    final values = <double>[];
    for (final s in samples.take(100)) {
      final eeg = s['eeg'];
      if (eeg is! Map) continue;
      for (final ch in ChannelRegions.attentionFrontal) {
        final v = (eeg[ch] as num?)?.toDouble();
        if (v != null) values.add(v);
      }
    }
    if (values.length < 8) return false;
    final inCqRange = values.every((v) => v >= -0.01 && v <= 4.51);
    if (!inCqRange) return false;
    final unique = values.map((v) => v.round()).toSet();
    return unique.length <= 5;
  }

  static bool _looksLikeRealEeg(List<Map<String, dynamic>> samples) {
    if (_looksLikeContactQualityEeg(samples)) return false;

    final values = <double>[];
    for (final s in samples.take(100)) {
      final eeg = s['eeg'];
      if (eeg is! Map) continue;
      for (final ch in ChannelRegions.attentionFrontal) {
        final v = (eeg[ch] as num?)?.toDouble();
        if (v != null) values.add(v);
      }
    }
    if (values.length < 16) return false;

    final mean = values.reduce((a, b) => a + b) / values.length;
    var varSum = 0.0;
    for (final v in values) {
      final d = v - mean;
      varSum += d * d;
    }
    final std = math.sqrt(varSum / values.length);
    // Sürekli sinyal: std anlamlı; CQ sahte EEG elendi
    return std > 0.5;
  }

  static SpectralBands _fromEegSeries(List<Map<String, dynamic>> samples) {
    if (samples.length < 8) return SpectralBands.zero;
    if (!_looksLikeRealEeg(samples)) return SpectralBands.zero;

    final fs = _estimateFs(samples);
    final perChannel = <SpectralBands>[];

    for (final ch in ChannelRegions.all) {
      final series = <double>[];
      for (final s in samples) {
        final eeg = s['eeg'];
        if (eeg is Map) {
          series.add((eeg[ch] as num?)?.toDouble() ?? 0);
        }
      }
      if (series.length < 8) continue;
      if (_isArtifactSeries(series)) continue;
      if (fs >= 32) {
        perChannel.add(_welchBands(series, fs));
      } else {
        // Undersampled buffer: göreli çok ölçekli enerji (yalnızca gerçek µV)
        perChannel.add(_multiscaleBands(series));
      }
    }

    if (perChannel.isEmpty) return SpectralBands.zero;

    var d = 0.0, t = 0.0, a = 0.0, b = 0.0, g = 0.0;
    for (final bp in perChannel) {
      d += bp.delta;
      t += bp.theta;
      a += bp.alpha;
      b += bp.beta;
      g += bp.gamma;
    }
    final n = perChannel.length.toDouble();
    return SpectralBands(
      delta: d / n,
      theta: t / n,
      alpha: a / n,
      beta: b / n,
      gamma: g / n,
    );
  }

  /// Düşük fs için ardışık fark / yumuşatma ile göreli bant enerjisi.
  /// Yalnızca gerçek µV serilerinde çağrılır (CQ 0–4 değil).
  static SpectralBands _multiscaleBands(List<double> x) {
    final detrended = _detrend(x);
    final e0 = _energy(detrended);
    if (e0 < 1e-18) return SpectralBands.zero;

    final d1 = _diff(detrended);
    final d2 = _diff(d1);
    final s1 = _smooth(detrended, 3);
    final s2 = _smooth(s1, 5);

    return SpectralBands(
      delta: _energy(s2),
      theta: _energy(_sub(s1, s2)),
      alpha: _energy(_sub(detrended, s1)),
      beta: _energy(d1),
      gamma: _energy(d2),
    );
  }

  static bool _isArtifactSeries(List<double> x) {
    if (x.length < 8) return true;
    final mean = x.reduce((a, b) => a + b) / x.length;
    var varSum = 0.0;
    var peak = 0.0;
    for (final v in x) {
      final d = v - mean;
      varSum += d * d;
      peak = math.max(peak, d.abs());
    }
    final std = math.sqrt(varSum / x.length);
    if (std < 1e-6) return true;
    if (std > 500 || peak > 1500) return true;
    return false;
  }

  /// Welch PSD → bant güçleri (Hann, %50 overlap).
  static SpectralBands _welchBands(List<double> x, double fs) {
    final detrended = _detrend(x);
    final n = detrended.length;
    if (n < 32) return SpectralBands.zero;

    var nperseg = math.min(fs.round().clamp(32, 256), n ~/ 2);
    if (nperseg % 2 == 1) nperseg -= 1;
    nperseg = math.max(32, nperseg);
    if (n < nperseg) return SpectralBands.zero;

    final noverlap = nperseg ~/ 2;
    final step = nperseg - noverlap;
    final half = nperseg ~/ 2;
    final acc = List<double>.filled(half + 1, 0);
    var segCount = 0;

    final window = List<double>.generate(nperseg, (i) {
      return 0.5 * (1 - math.cos(2 * math.pi * i / (nperseg - 1)));
    });
    final winPower = window.fold<double>(0, (s, w) => s + w * w);

    for (var start = 0; start + nperseg <= n; start += step) {
      for (var k = 0; k <= half; k++) {
        var re = 0.0;
        var im = 0.0;
        for (var i = 0; i < nperseg; i++) {
          final v = detrended[start + i] * window[i];
          final angle = -2 * math.pi * k * i / nperseg;
          re += v * math.cos(angle);
          im += v * math.sin(angle);
        }
        acc[k] += (re * re + im * im) / (fs * winPower);
      }
      segCount++;
    }

    if (segCount == 0) return SpectralBands.zero;
    for (var k = 0; k <= half; k++) {
      acc[k] /= segCount;
    }

    double band(double lo, double hi) {
      var sum = 0.0;
      final hiEff = math.min(hi, fs / 2);
      for (var k = 0; k <= half; k++) {
        final f = k * fs / nperseg;
        if (f >= lo && f < hiEff) sum += acc[k];
      }
      return sum;
    }

    return SpectralBands(
      delta: band(0.5, 4),
      theta: band(4, 8),
      alpha: band(8, 13),
      beta: band(13, 30),
      gamma: band(30, math.min(45, fs / 2)),
    );
  }

  static double _estimateFs(List<Map<String, dynamic>> samples) {
    DateTime? first;
    DateTime? last;
    for (final s in samples) {
      final t = _parseTime(s);
      if (t == null) continue;
      first ??= t;
      last = t;
    }
    if (first == null || last == null || identical(first, last)) return 2.0;
    final sec = last.difference(first).inMilliseconds / 1000.0;
    if (sec <= 0) return 2.0;
    return (samples.length - 1) / sec;
  }

  static DateTime? _parseTime(Map<String, dynamic> s) {
    final raw = s['capturedAt'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static List<double> _detrend(List<double> x) {
    final mean = x.reduce((a, b) => a + b) / x.length;
    return x.map((v) => v - mean).toList();
  }

  static List<double> _diff(List<double> x) {
    if (x.length < 2) return const [];
    return List.generate(x.length - 1, (i) => x[i + 1] - x[i]);
  }

  static List<double> _smooth(List<double> x, int win) {
    if (x.isEmpty) return const [];
    final half = win ~/ 2;
    return List.generate(x.length, (i) {
      var sum = 0.0;
      var n = 0;
      for (var j = i - half; j <= i + half; j++) {
        if (j >= 0 && j < x.length) {
          sum += x[j];
          n++;
        }
      }
      return n == 0 ? 0.0 : sum / n;
    });
  }

  static List<double> _sub(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    return List.generate(n, (i) => a[i] - b[i]);
  }

  static double _energy(List<double> x) {
    if (x.isEmpty) return 0;
    var s = 0.0;
    for (final v in x) {
      s += v * v;
    }
    return s / x.length;
  }
}
