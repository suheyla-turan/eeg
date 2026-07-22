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
  final double mentalFatigue;
  final double distraction;
  final double alpha;
  final double beta;
  final double theta;
  final double delta;
  final double gamma;
  final double thetaBeta;
  final double alphaBeta;
  final double betaAlpha;
  final int sampleCount;
  final int durationSeconds;
  final bool dataInsufficient;

  const PhaseMetrics({
    required this.phase,
    this.attention = 0,
    this.focus = 0,
    this.stress = 0,
    this.engagement = 0,
    this.relaxation = 0,
    this.interest = 0,
    this.excitement = 0,
    this.mentalFatigue = 0,
    this.distraction = 0,
    this.alpha = 0,
    this.beta = 0,
    this.theta = 0,
    this.delta = 0,
    this.gamma = 0,
    this.thetaBeta = 0,
    this.alphaBeta = 0,
    this.betaAlpha = 0,
    this.sampleCount = 0,
    this.durationSeconds = 0,
    this.dataInsufficient = false,
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
      'mentalFatigue': mentalFatigue,
      'distraction': distraction,
      'alpha': alpha,
      'beta': beta,
      'theta': theta,
      'delta': delta,
      'gamma': gamma,
      'thetaBeta': thetaBeta,
      'alphaBeta': alphaBeta,
      'betaAlpha': betaAlpha,
      'sampleCount': sampleCount,
      'durationSeconds': durationSeconds,
      'dataInsufficient': dataInsufficient,
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
      mentalFatigue: (map['mentalFatigue'] as num?)?.toDouble() ?? 0,
      distraction: (map['distraction'] as num?)?.toDouble() ?? 0,
      alpha: (map['alpha'] as num?)?.toDouble() ?? 0,
      beta: (map['beta'] as num?)?.toDouble() ?? 0,
      theta: (map['theta'] as num?)?.toDouble() ?? 0,
      delta: (map['delta'] as num?)?.toDouble() ?? 0,
      gamma: (map['gamma'] as num?)?.toDouble() ?? 0,
      thetaBeta: (map['thetaBeta'] as num?)?.toDouble() ?? 0,
      alphaBeta: (map['alphaBeta'] as num?)?.toDouble() ?? 0,
      betaAlpha: (map['betaAlpha'] as num?)?.toDouble() ?? 0,
      sampleCount: (map['sampleCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      dataInsufficient: map['dataInsufficient'] as bool? ?? false,
    );
  }
}
