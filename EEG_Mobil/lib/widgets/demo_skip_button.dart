import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Demo modunda sağ alta gösterilen hızlı geç butonu.
class DemoSkipButton extends StatelessWidget {
  const DemoSkipButton({
    super.key,
    required this.onPressed,
    this.label = 'Geç',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final demoMode = context.watch<SettingsProvider>().demoMode;
    if (!demoMode) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          heroTag: null,
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.skip_next_rounded),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
