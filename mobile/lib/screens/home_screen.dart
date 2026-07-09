import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/eeg_session_controller.dart';
import '../widgets/connection_banner.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/emotion_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _defaultEmotions = [
    ('mutluluk', 'Mutluluk'),
    ('ofke', 'Öfke'),
    ('uyku', 'Uyku Hali'),
    ('stres', 'Stres'),
    ('odak', 'Odak'),
    ('uzuntu', 'Üzüntü'),
    ('sakinlik', 'Sakinlik'),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<EegSessionController>(
      builder: (context, controller, _) {
        final snapshot = controller.snapshot;
        final emotions = snapshot.emotions.isEmpty
            ? _defaultEmotions
                .map(
                  (item) => EmotionScore(
                    key: item.$1,
                    label: item.$2,
                    status: 'pending_ai',
                  ),
                )
                .toList()
            : snapshot.emotions;

        return Scaffold(
          appBar: AppBar(
            title: const Text('EEG AI'),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.connect,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ConnectionBanner(
                  device: snapshot.device,
                  connectionState: controller.connectionState,
                  errorMessage: controller.errorMessage,
                ),
                const SizedBox(height: 16),
                EegChart(
                  samples: controller.recentSamples,
                  channelCount: snapshot.latestEeg?.channelCount ?? 0,
                ),
                const SizedBox(height: 20),
                Text(
                  'Duygu Yorumlama',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI modeli eklendiğinde mutluluk, öfke, uyku ve diğer durumlar burada skorlanacak.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: emotions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    return EmotionCard(emotion: emotions[index]);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
