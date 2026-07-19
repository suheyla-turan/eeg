/// Bir deney aşaması (Baseline / Reels / Metin) için özet skorlar.
class PhaseMetrics {
  final String phase;
  final double attention;
  final double focus;
  final double stress;
  final double engagement;
  final double relaxation;
  final double interest;
  final double excitement;
  final double alpha;
  final double beta;
  final double theta;
  final double delta;
  final double gamma;
  final int sampleCount;
  final int durationSeconds;

  const PhaseMetrics({
    required this.phase,
    this.attention = 0,
    this.focus = 0,
    this.stress = 0,
    this.engagement = 0,
    this.relaxation = 0,
    this.interest = 0,
    this.excitement = 0,
    this.alpha = 0,
    this.beta = 0,
    this.theta = 0,
    this.delta = 0,
    this.gamma = 0,
    this.sampleCount = 0,
    this.durationSeconds = 0,
  });

  static const empty = PhaseMetrics(phase: '');

  Map<String, dynamic> toMap() {
    return {
      'phase': phase,
      'attention': attention,
      'focus': focus,
      'stress': stress,
      'engagement': engagement,
      'relaxation': relaxation,
      'interest': interest,
      'excitement': excitement,
      'alpha': alpha,
      'beta': beta,
      'theta': theta,
      'delta': delta,
      'gamma': gamma,
      'sampleCount': sampleCount,
      'durationSeconds': durationSeconds,
    };
  }

  factory PhaseMetrics.fromMap(Map<String, dynamic> map) {
    return PhaseMetrics(
      phase: map['phase'] as String? ?? '',
      attention: (map['attention'] as num?)?.toDouble() ?? 0,
      focus: (map['focus'] as num?)?.toDouble() ?? 0,
      stress: (map['stress'] as num?)?.toDouble() ?? 0,
      engagement: (map['engagement'] as num?)?.toDouble() ?? 0,
      relaxation: (map['relaxation'] as num?)?.toDouble() ?? 0,
      interest: (map['interest'] as num?)?.toDouble() ?? 0,
      excitement: (map['excitement'] as num?)?.toDouble() ?? 0,
      alpha: (map['alpha'] as num?)?.toDouble() ?? 0,
      beta: (map['beta'] as num?)?.toDouble() ?? 0,
      theta: (map['theta'] as num?)?.toDouble() ?? 0,
      delta: (map['delta'] as num?)?.toDouble() ?? 0,
      gamma: (map['gamma'] as num?)?.toDouble() ?? 0,
      sampleCount: (map['sampleCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
