import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';
import '../data/sensors.dart';
import '../theme/app_colors.dart';

class BrainMap extends StatelessWidget {
  final Map<String, ContactQuality> quality;
  final Map<String, double> bandPower;

  const BrainMap({
    super.key,
    required this.quality,
    required this.bandPower,
  });

  static const _positions = <String, Offset>{
    'AF3': Offset(0.32, 0.14),
    'AF4': Offset(0.68, 0.14),
    'F7': Offset(0.14, 0.28),
    'F3': Offset(0.34, 0.30),
    'F4': Offset(0.66, 0.30),
    'F8': Offset(0.86, 0.28),
    'FC5': Offset(0.22, 0.42),
    'FC6': Offset(0.78, 0.42),
    'T7': Offset(0.08, 0.52),
    'T8': Offset(0.92, 0.52),
    'P7': Offset(0.22, 0.68),
    'P8': Offset(0.78, 0.68),
    'O1': Offset(0.36, 0.84),
    'O2': Offset(0.64, 0.84),
  };

  static const _size = 280.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: AppColors.mapBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.mapRing, width: 2),
                ),
              ),
              Positioned(
                top: -8,
                left: _size / 2 - 10,
                child: Container(
                  width: 20,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.mapRing,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                ),
              ),
              Positioned(
                left: -10,
                top: _size * 0.42,
                child: Container(
                  width: 14,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mapRing,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                right: -10,
                top: _size * 0.42,
                child: Container(
                  width: 14,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mapRing,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                bottom: 18,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),
              ...sensorIds.map((id) {
                final pos = _positions[id];
                if (pos == null) return const SizedBox.shrink();
                final q = quality[id] ?? ContactQuality.none;
                final power = bandPower[id] ?? 0.3;
                return Positioned(
                  left: pos.dx * _size - 17,
                  top: pos.dy * _size - 17,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _activityColor(power),
                      shape: BoxShape.circle,
                      border: Border.all(color: _qualityColor(q), width: 2.5),
                    ),
                    child: Text(
                      id,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.qualityGood, label: 'İyi temas'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.qualityFair, label: 'Orta'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.qualityPoor, label: 'Zayıf'),
          ],
        ),
      ],
    );
  }

  Color _qualityColor(ContactQuality q) {
    switch (q) {
      case ContactQuality.good:
        return AppColors.qualityGood;
      case ContactQuality.fair:
        return AppColors.qualityFair;
      case ContactQuality.poor:
        return AppColors.qualityPoor;
      case ContactQuality.none:
        return AppColors.textMuted;
    }
  }

  Color _activityColor(double value) {
    final t = value.clamp(0.0, 1.0);
    final r = (13 + (80 - 13) * t).round();
    final g = (122 + (200 - 122) * t).round();
    final b = (140 + (210 - 140) * t).round();
    return Color.fromARGB(255, r, g, b);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
