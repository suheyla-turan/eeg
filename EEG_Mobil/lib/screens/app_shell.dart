import 'package:flutter/material.dart';

import '../models/participant.dart';
import '../theme/app_colors.dart';
import 'history_screen.dart';
import 'home_eeg_shell.dart';
import 'new_participant_screen.dart';
import 'participant_registration_screen.dart';
import 'participants_screen.dart';
import 'settings_screen.dart';
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

  Widget _body() {
    switch (_destination) {
      case AppDestination.home:
        return WelcomeScreen(
          onStartExperiment: () => goTo(AppDestination.startExperiment),
          onRegisterParticipant: () =>
              goTo(AppDestination.registerParticipant),
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
          embeddedInShell: true,
          onRegistered: openExperimentAfterRegistration,
        );
      case AppDestination.participants:
        return const ParticipantsScreen(embeddedInShell: true);
      case AppDestination.videos:
        return const VideosScreen(embeddedInShell: true);
      case AppDestination.texts:
        return const TextsScreen(embeddedInShell: true);
      case AppDestination.eeg:
        return const HomeEegShell(embeddedInShell: true);
      case AppDestination.history:
        return const HistoryScreen(embeddedInShell: true);
      case AppDestination.settings:
        return const SettingsScreen(embeddedInShell: true);
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
          goTo(dest);
        },
      ),
      body: _body(),
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
                  Icon(Icons.psychology_outlined, size: 36, color: scheme.primary),
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
