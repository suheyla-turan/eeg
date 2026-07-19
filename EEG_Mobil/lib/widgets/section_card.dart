import 'package:flutter/material.dart';

/// Tema uyumlu bölüm kartı (Material 3).
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? right;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.right,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? scheme.outlineVariant
              : scheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (right != null) ...[const SizedBox(width: 12), right!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
