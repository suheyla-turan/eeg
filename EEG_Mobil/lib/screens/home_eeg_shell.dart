import 'package:flutter/material.dart';

import 'ai_analysis_screen.dart';
import 'live_eeg_screen.dart';
import 'live_stream_screen.dart';
import 'sensor_info_screen.dart';

/// EEG izleme sekmeleri — kabuk menüsünden açılır.
class HomeEegShell extends StatefulWidget {
  const HomeEegShell({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<HomeEegShell> createState() => _HomeEegShellState();
}

class _HomeEegShellState extends State<HomeEegShell> {
  int _index = 0;

  static const _pages = [
    LiveEegScreen(),
    LiveStreamScreen(),
    AiAnalysisScreen(),
    SensorInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(title: const Text('EEG Bağlantısı')),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Durum',
          ),
          NavigationDestination(
            icon: Icon(Icons.ssid_chart_outlined),
            selectedIcon: Icon(Icons.ssid_chart),
            label: 'Akış',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Sensör',
          ),
        ],
      ),
    );
  }
}
