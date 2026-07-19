import 'package:flutter/material.dart';

import '../core/app_page_route.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_nav_card.dart';
import 'ai_analysis_screen.dart';
import 'live_eeg_screen.dart';
import 'live_stream_screen.dart';
import 'sensor_info_screen.dart';

/// EEG izleme — 4 sayfa ayrı ayrı seçilebilir.
class HomeEegShell extends StatelessWidget {
  const HomeEegShell({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  static const _items = <_EegNavItem>[
    _EegNavItem(
      title: 'Durum',
      subtitle: 'Bağlantı durumu, batarya ve temas kalitesi',
      icon: Icons.monitor_heart_outlined,
      pageBuilder: LiveEegScreen.new,
    ),
    _EegNavItem(
      title: 'Akış',
      subtitle: 'Canlı EEG sinyali ve grafik akışı',
      icon: Icons.ssid_chart_outlined,
      pageBuilder: LiveStreamScreen.new,
    ),
    _EegNavItem(
      title: 'AI Analiz',
      subtitle: 'Duygu ve bölge analizi',
      icon: Icons.psychology_outlined,
      pageBuilder: AiAnalysisScreen.new,
    ),
    _EegNavItem(
      title: 'Sensör',
      subtitle: 'Sensör bilgileri ve kanal detayları',
      icon: Icons.info_outline,
      pageBuilder: SensorInfoScreen.new,
    ),
  ];

  void _open(BuildContext context, _EegNavItem item) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.sharedAxisX,
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(item.title)),
          body: item.pageBuilder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = ResponsiveBody(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: ListView(
        children: [
          Text(
            'EEG Bağlantısı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'İzlemek istediğiniz sayfayı seçin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary(context),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: _items[i].title,
              subtitle: _items[i].subtitle,
              icon: _items[i].icon,
              accent: scheme.primary,
              onTap: () => _open(context, _items[i]),
            ),
          ],
        ],
      ),
    );

    if (embeddedInShell) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('EEG Bağlantısı')),
      body: SafeArea(child: body),
    );
  }
}

class _EegNavItem {
  const _EegNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pageBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() pageBuilder;
}
