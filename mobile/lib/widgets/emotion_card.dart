import 'package:flutter/material.dart';

import '../models/app_models.dart';

class EmotionCard extends StatelessWidget {
  const EmotionCard({
    super.key,
    required this.emotion,
  });

  final EmotionScore emotion;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'mutluluk':
        return Icons.sentiment_very_satisfied_outlined;
      case 'ofke':
        return Icons.sentiment_very_dissatisfied_outlined;
      case 'uyku':
        return Icons.bedtime_outlined;
      case 'stres':
        return Icons.psychology_alt_outlined;
      case 'odak':
        return Icons.center_focus_strong_outlined;
      case 'uzuntu':
        return Icons.sentiment_dissatisfied_outlined;
      case 'sakinlik':
        return Icons.spa_outlined;
      default:
        return Icons.emoji_emotions_outlined;
    }
  }

  Color _colorForKey(BuildContext context, String key) {
    final colors = Theme.of(context).colorScheme;
    switch (key) {
      case 'mutluluk':
        return Colors.amber.shade700;
      case 'ofke':
        return Colors.red.shade700;
      case 'uyku':
        return Colors.indigo.shade400;
      case 'stres':
        return Colors.deepOrange.shade400;
      case 'odak':
        return Colors.teal.shade600;
      case 'uzuntu':
        return Colors.blue.shade700;
      case 'sakinlik':
        return Colors.green.shade600;
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _colorForKey(context, emotion.key);
    final scoreText = emotion.isPending
        ? 'AI bekleniyor'
        : '${((emotion.score ?? 0) * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForKey(emotion.key), color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  emotion.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            scoreText,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: emotion.isPending ? null : emotion.score,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: accent.withValues(alpha: 0.15),
            color: accent,
          ),
        ],
      ),
    );
  }
}
