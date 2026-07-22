import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';
import '../theme/app_colors.dart';

class EmotionBar extends StatelessWidget {
  final EmotionScore emotion;

  const EmotionBar({super.key, required this.emotion});

  @override
  Widget build(BuildContext context) {
    final score = emotion.score.clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: emotion.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    emotion.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 10,
                backgroundColor: AppColors.surfaceMuted,
                color: emotion.color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '$score%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
