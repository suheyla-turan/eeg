import '../data/sensors.dart';

/// Python API'den gelen tek EEG örneği (14 kanal + timestamp).
class EegSample {
  final double timestamp;
  final double af3;
  final double f7;
  final double f3;
  final double fc5;
  final double t7;
  final double p7;
  final double o1;
  final double o2;
  final double p8;
  final double t8;
  final double fc6;
  final double f4;
  final double f8;
  final double af4;

  const EegSample({
    required this.timestamp,
    required this.af3,
    required this.f7,
    required this.f3,
    required this.fc5,
    required this.t7,
    required this.p7,
    required this.o1,
    required this.o2,
    required this.p8,
    required this.t8,
    required this.fc6,
    required this.f4,
    required this.f8,
    required this.af4,
  });

  static const List<String> channels = [
    'AF3',
    'F7',
    'F3',
    'FC5',
    'T7',
    'P7',
    'O1',
    'O2',
    'P8',
    'T8',
    'FC6',
    'F4',
    'F8',
    'AF4',
  ];

  factory EegSample.empty({double? timestamp}) {
    return EegSample(
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch / 1000.0,
      af3: 0,
      f7: 0,
      f3: 0,
      fc5: 0,
      t7: 0,
      p7: 0,
      o1: 0,
      o2: 0,
      p8: 0,
      t8: 0,
      fc6: 0,
      f4: 0,
      f8: 0,
      af4: 0,
    );
  }

  factory EegSample.fromJson(Map<String, dynamic>? json) {
    if (json == null) return EegSample.empty();
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return EegSample(
      timestamp: (json['timestamp'] as num?)?.toDouble() ??
          DateTime.now().millisecondsSinceEpoch / 1000.0,
      af3: read('AF3'),
      f7: read('F7'),
      f3: read('F3'),
      fc5: read('FC5'),
      t7: read('T7'),
      p7: read('P7'),
      o1: read('O1'),
      o2: read('O2'),
      p8: read('P8'),
      t8: read('T8'),
      fc6: read('FC6'),
      f4: read('F4'),
      f8: read('F8'),
      af4: read('AF4'),
    );
  }

  /// Contact quality (0–4) değerlerinden grafik için örnek üretir.
  factory EegSample.fromContactQuality(
    Map<String, int> quality, {
    double? timestamp,
  }) {
    double q(String id) => (quality[id] ?? 0).toDouble();
    return EegSample(
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch / 1000.0,
      af3: q('AF3'),
      f7: q('F7'),
      f3: q('F3'),
      fc5: q('FC5'),
      t7: q('T7'),
      p7: q('P7'),
      o1: q('O1'),
      o2: q('O2'),
      p8: q('P8'),
      t8: q('T8'),
      fc6: q('FC6'),
      f4: q('F4'),
      f8: q('F8'),
      af4: q('AF4'),
    );
  }

  double operator [](String channel) {
    return switch (channel) {
      'AF3' => af3,
      'F7' => f7,
      'F3' => f3,
      'FC5' => fc5,
      'T7' => t7,
      'P7' => p7,
      'O1' => o1,
      'O2' => o2,
      'P8' => p8,
      'T8' => t8,
      'FC6' => fc6,
      'F4' => f4,
      'F8' => f8,
      'AF4' => af4,
      _ => 0,
    };
  }

  Map<String, double> get channelMap => {
        for (final id in sensorIds) id: this[id],
      };

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'AF3': af3,
        'F7': f7,
        'F3': f3,
        'FC5': fc5,
        'T7': t7,
        'P7': p7,
        'O1': o1,
        'O2': o2,
        'P8': p8,
        'T8': t8,
        'FC6': fc6,
        'F4': f4,
        'F8': f8,
        'AF4': af4,
      };

  bool get hasSignal => channelMap.values.any((v) => v.abs() > 0.0001);
}
