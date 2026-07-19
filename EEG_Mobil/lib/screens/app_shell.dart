import 'package:flutter/material.dart';

import '../core/app_page_route.dart';
import '../models/participant.dart';
import '../theme/app_colors.dart';
import '../widgets/participant_select_sheet.dart';
import 'history_screen.dart';
import 'home_eeg_shell.dart';
import 'new_participant_screen.dart';
import 'participant_registration_screen.dart';
import 'participants_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'texts_screen.dart';
import 'videos_screen.dart';
import 'welcome_screen.dart';

enum AppDestination {
  home,
  startExperiment,
  registerParticipant,
  participants,
  videos,
  texts,
  eeg,
  history,
  statistics,
  settings,
}

/// Hamburger menülü ana kabuk — tek yerden gezinme.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();

  static AppShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();
}

class AppShellState extends State<AppShell> {
  AppDestination _destination = AppDestination.home;
  Participant? _experimentParticipant;

  static const _titles = <AppDestination, String>{
    AppDestination.home: 'EEG Araştırma',
    AppDestination.startExperiment: 'Deney Başlat',
    AppDestination.registerParticipant: 'Katılımcı Kaydı',
    AppDestination.participants: 'Katılımcılar',
    AppDestination.videos: 'Videolar',
    AppDestination.texts: 'Metinler',
    AppDestination.eeg: 'EEG Bağlantısı',
    AppDestination.history: 'Geçmiş Deneyler',
    AppDestination.statistics: 'İstatistikler',
    AppDestination.settings: 'Ayarlar',
  };

  void goTo(
    AppDestination destination, {
    Participant? experimentParticipant,
  }) {
    setState(() {
      _destination = destination;
      if (destination == AppDestination.startExperiment) {
        _experimentParticipant = experimentParticipant;
      }
      if (destination == AppDestination.registerParticipant) {
        _experimentParticipant = null;
      }
    });
  }

  /// Kayıt sonrası deney ekranına geçiş.
  void openExperimentAfterRegistration(Participant participant) {
    goTo(
      AppDestination.startExperiment,
      experimentParticipant: participant,
    );
  }

  Future<void> openParticipantSelect() async {
    await showParticipantSelectSheet(
      context,
      onSelectExisting: (participant) {
        goTo(
          AppDestination.startExperiment,
          experimentParticipant: participant,
        );
      },
      onAddNew: () => goTo(AppDestination.registerParticipant),
    );
  }

  Widget _body() {
    switch (_destination) {
      case AppDestination.home:
        return WelcomeScreen(
          key: const ValueKey('home'),
          onStartExperiment: openParticipantSelect,
          onParticipants: () => goTo(AppDestination.participants),
          onHistory: () => goTo(AppDestination.history),
          onStatistics: () => goTo(AppDestination.statistics),
          onSettings: () => goTo(AppDestination.settings),
          onOpenEeg: () => goTo(AppDestination.eeg),
        );
      case AppDestination.startExperiment:
        return NewParticipantScreen(
          key: ValueKey(_experimentParticipant?.participantId ?? 'new'),
          existingParticipant: _experimentParticipant,
          embeddedInShell: true,
        );
      case AppDestination.registerParticipant:
        return ParticipantRegistrationScreen(
          key: const ValueKey('register'),
          embeddedInShell: true,
          onRegistered: openExperimentAfterRegistration,
        );
      case AppDestination.participants:
        return const ParticipantsScreen(
          key: ValueKey('participants'),
          embeddedInShell: true,
        );
      case AppDestination.videos:
        return const VideosScreen(
          key: ValueKey('videos'),
          embeddedInShell: true,
        );
      case AppDestination.texts:
        return const TextsScreen(
          key: ValueKey('texts'),
          embeddedInShell: true,
        );
      case AppDestination.eeg:
        return const HomeEegShell(
          key: ValueKey('eeg'),
          embeddedInShell: true,
        );
      case AppDestination.history:
        return const HistoryScreen(
          key: ValueKey('history'),
          embeddedInShell: true,
        );
      case AppDestination.statistics:
        return const StatisticsScreen(
          key: ValueKey('stats'),
          embeddedInShell: true,
        );
      case AppDestination.settings:
        return const SettingsScreen(
          key: ValueKey('settings'),
          embeddedInShell: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_destination] ?? 'EEG Araştırma'),
      ),
      drawer: _AppDrawer(
        current: _destination,
        onSelect: (dest) {
          Navigator.of(context).pop();
          if (dest == AppDestination.startExperiment) {
            openParticipantSelect();
            return;
          }
          goTo(dest);
        },
      ),
      body: FadeThroughSwitcher(
        child: KeyedSubtree(
          key: ValueKey(_destination),
          child: _body(),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.current,
    required this.onSelect,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.softPrimary(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 36, color: scheme.primary),
                  const Spacer(),
                  Text(
                    'EEG Araştırma',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Menüden sayfa seçin',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary(context),
                        ),
                  ),
                ],
              ),
            ),
            _item(
              context,
              dest: AppDestination.home,
              icon: Icons.home_outlined,
              label: 'Ana Sayfa',
            ),
            const _DrawerSection('Deney'),
            _item(
              context,
              dest: AppDestination.startExperiment,
              icon: Icons.play_circle_outline,
              label: 'Deney Başlat',
            ),
            _item(
              context,
              dest: AppDestination.registerParticipant,
              icon: Icons.person_add_alt_1_outlined,
              label: 'Katılımcı Kaydı',
            ),
            const _DrawerSection('İçerik'),
            _item(
              context,
              dest: AppDestination.videos,
              icon: Icons.videocam_outlined,
              label: 'Videolar',
            ),
            _item(
              context,
              dest: AppDestination.texts,
              icon: Icons.article_outlined,
              label: 'Metinler',
            ),
            const _DrawerSection('Veri'),
            _item(
              context,
              dest: AppDestination.participants,
              icon: Icons.groups_outlined,
              label: 'Katılımcılar',
            ),
            _item(
              context,
              dest: AppDestination.history,
              icon: Icons.history_outlined,
              label: 'Geçmiş Deneyler',
            ),
            _item(
              context,
              dest: AppDestination.statistics,
              icon: Icons.insights_outlined,
              label: 'İstatistikler',
            ),
            const _DrawerSection('Sistem'),
            _item(
              context,
              dest: AppDestination.eeg,
              icon: Icons.monitor_heart_outlined,
              label: 'EEG Bağlantısı',
            ),
            _item(
              context,
              dest: AppDestination.settings,
              icon: Icons.settings_outlined,
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required AppDestination dest,
    required IconData icon,
    required String label,
  }) {
    final selected = current == dest;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: selected ? scheme.primary : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.primary : null,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.softPrimary(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () => onSelect(dest),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.hint(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
