import 'package:flutter/material.dart';

import '../core/responsive.dart';
import 'history_screen.dart';
import 'home_eeg_shell.dart';
import 'new_participant_screen.dart';
import 'participant_registration_screen.dart';
import 'participants_screen.dart';
import 'settings_screen.dart';
import 'texts_screen.dart';
import 'videos_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _items = <_HomeNavItem>[
    _HomeNavItem(
      title: 'Yeni Katılımcı',
      subtitle: 'Katılımcı kaydı oluştur',
      icon: Icons.person_add_alt_1_outlined,
      color: Color(0xFF0D7A8C),
    ),
    _HomeNavItem(
      title: 'Katılımcılar',
      subtitle: 'Kayıtlı katılımcı listesi',
      icon: Icons.groups_outlined,
      color: Color(0xFF1FA8A0),
    ),
    _HomeNavItem(
      title: 'Videolar',
      subtitle: 'Video ekle / düzenle',
      icon: Icons.videocam_outlined,
      color: Color(0xFF3B7DD8),
    ),
    _HomeNavItem(
      title: 'Metinler',
      subtitle: 'Metin ekle / düzenle',
      icon: Icons.article_outlined,
      color: Color(0xFF6B5CE7),
    ),
    _HomeNavItem(
      title: 'EEG Bağlantısı',
      subtitle: 'Canlı EEG izleme',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFFC44B4B),
    ),
    _HomeNavItem(
      title: 'Geçmiş Deneyler',
      subtitle: 'Tamamlanan ve iptal edilen oturumlar',
      icon: Icons.history_outlined,
      color: Color(0xFFD4A017),
    ),
    _HomeNavItem(
      title: 'Ayarlar',
      subtitle: 'API · Tema · Loglar',
      icon: Icons.settings_outlined,
      color: Color(0xFF5A6F7A),
    ),
  ];

  void _open(BuildContext context, int index) {
    final Widget page;
    switch (index) {
      case 0:
        page = const ParticipantRegistrationScreen();
      case 1:
        page = const ParticipantsScreen();
      case 2:
        page = const VideosScreen();
      case 3:
        page = const TextsScreen();
      case 4:
        page = const HomeEegShell();
      case 5:
        page = const HistoryScreen();
      case 6:
        page = const SettingsScreen();
      default:
        page = const ParticipantRegistrationScreen();
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = context.gridColumns(
              phone: 2,
              tablet: 3,
              desktop: 4,
            );
            final aspect = width >= 900
                ? 1.35
                : width >= 600
                    ? 1.25
                    : 1.05;
            final maxContent = width >= Breakpoints.tablet ? 1100.0 : width;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        context.isTablet ? 28 : 20,
                        24,
                        context.isTablet ? 28 : 20,
                        8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EEG Araştırma',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tek cihaz · giriş yok · araştırma oturumu',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NewParticipantScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_circle_outline),
                                label: const Text('Deney Başlat'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        context.isTablet ? 24 : 16,
                        8,
                        context.isTablet ? 24 : 16,
                        28,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: aspect,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _items[index];
                            return _HomeCard(
                              item: item,
                              onTap: () => _open(context, index),
                            );
                          },
                          childCount: _items.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeNavItem {
  const _HomeNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.item, required this.onTap});

  final _HomeNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const Spacer(),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
