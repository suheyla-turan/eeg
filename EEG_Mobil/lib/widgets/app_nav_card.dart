import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Ana sayfa ve menü için modern navigasyon kartı.
class AppNavCard extends StatefulWidget {
  const AppNavCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<AppNavCard> createState() => _AppNavCardState();
}

class _AppNavCardState extends State<AppNavCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent ?? scheme.primary;
    final elevation = _pressed ? 1.0 : 3.0;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.line(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.04 : 0.07),
              blurRadius: elevation * 4,
              offset: Offset(0, elevation),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.iconBox,
                    height: AppSpacing.iconBox,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondary(context),
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.hint(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
