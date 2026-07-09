import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.$2,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  (Color, Color) _palette(StatusTone tone) {
    switch (tone) {
      case StatusTone.success:
        return (const Color(0xFFE4F5EB), AppColors.success);
      case StatusTone.warning:
        return (const Color(0xFFFBF0D4), AppColors.warning);
      case StatusTone.danger:
        return (const Color(0xFFF8E4E4), AppColors.danger);
      case StatusTone.info:
        return (AppColors.primarySoft, AppColors.primary);
      case StatusTone.neutral:
        return (AppColors.surfaceMuted, AppColors.textSecondary);
    }
  }
}

enum StatusTone { neutral, success, warning, danger, info }
