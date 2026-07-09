import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';
import '../data/sensors.dart';
import '../theme/app_colors.dart';

class ContactQualityGrid extends StatelessWidget {
  final Map<String, ContactQuality> quality;

  const ContactQualityGrid({super.key, required this.quality});

  static const _labels = {
    ContactQuality.good: 'İyi',
    ContactQuality.fair: 'Orta',
    ContactQuality.poor: 'Zayıf',
    ContactQuality.none: 'Yok',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sensorIds.map((id) {
        final q = quality[id] ?? ContactQuality.none;
        final tone = _tone(q);
        return Container(
          width: (MediaQuery.sizeOf(context).width - 72) / 4,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                id,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.$1,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _labels[q]!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tone.$2,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  (Color, Color) _tone(ContactQuality q) {
    switch (q) {
      case ContactQuality.good:
        return (const Color(0xFFE4F5EB), AppColors.qualityGood);
      case ContactQuality.fair:
        return (const Color(0xFFFBF0D4), AppColors.qualityFair);
      case ContactQuality.poor:
        return (const Color(0xFFF8E4E4), AppColors.qualityPoor);
      case ContactQuality.none:
        return (AppColors.surfaceMuted, AppColors.textMuted);
    }
  }
}
