import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Deney adımları için ortak Material 3 iskelet.
/// Uygulama teması / AppBar dili ile uyumludur.
class ExperimentScaffold extends StatelessWidget {
  const ExperimentScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.backgroundColor,
    this.showAppBar = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool showAppBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.pageBg(context),
        appBar: showAppBar
            ? AppBar(
                title: title != null ? Text(title!) : null,
                backgroundColor: theme.appBarTheme.backgroundColor,
                foregroundColor: theme.appBarTheme.foregroundColor,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                actions: actions,
              )
            : null,
        body: SafeArea(child: child),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

/// Bilgilendirme adımlarında geri sayım + Hazırım düzeni.
class BriefingActions extends StatelessWidget {
  const BriefingActions({
    super.key,
    required this.secondsLeft,
    required this.onReady,
    this.readyLabel = 'Hazırım',
    this.totalSeconds = 15,
  });

  final int secondsLeft;
  final VoidCallback onReady;
  final String readyLabel;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        totalSeconds <= 0 ? 1.0 : 1.0 - (secondsLeft / totalSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$secondsLeft sn',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.muted(context),
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: onReady,
          child: Text(readyLabel),
        ),
      ],
    );
  }
}
