import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uygulama açılış / proje tanıtım sayfası.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onStartExperiment,
    required this.onRegisterParticipant,
    this.onOpenEeg,
  });

  final VoidCallback onStartExperiment;
  final VoidCallback onRegisterParticipant;
  final VoidCallback? onOpenEeg;

  static const _steps = <_FlowStep>[
    _FlowStep(
      number: '1',
      title: 'Katılımcı kaydı',
      detail: 'Demografik bilgiler ve alışkanlıklar kaydedilir.',
      icon: Icons.person_add_alt_1_outlined,
    ),
    _FlowStep(
      number: '2',
      title: 'Deney başlatma',
      detail: 'Deney tipi seçilir; tam protokol veya tek aşama.',
      icon: Icons.play_circle_outline,
    ),
    _FlowStep(
      number: '3',
      title: 'EEG + içerik',
      detail: 'Baseline, Reels ve metin okuma sırasında EEG kaydı.',
      icon: Icons.monitor_heart_outlined,
    ),
    _FlowStep(
      number: '4',
      title: 'Analiz ve sonuç',
      detail: 'Oturum tamamlanır; sonuçlar ve geçmiş saklanır.',
      icon: Icons.analytics_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = AppColors.isDark(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF16333A), Color(0xFF1C282E)]
                    : const [Color(0xFFD6EEF2), Color(0xFFE8F5F3)],
              ),
              border: Border.all(color: AppColors.line(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology_outlined, size: 36, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  'EEG Araştırma',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sosyal medya (Reels) ve metin okuma sırasında beyin '
                  'aktivitesini EEG ile ölçen tek cihazlı araştırma uygulaması.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondary(context),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Proje amacı',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Katılımcıların kısa video akışı ve kontrollü metin okuma '
            'sırasındaki EEG yanıtlarını kaydetmek; oturumları güvenli şekilde '
            'saklayıp analiz edilebilir hale getirmek.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary(context),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 22),
          Text(
            'Nasıl ilerler?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          ..._steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StepTile(step: step),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onStartExperiment,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Deneye başla'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRegisterParticipant,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Önce katılımcı kaydet'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (onOpenEeg != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpenEeg,
              icon: const Icon(Icons.bluetooth_searching_outlined, size: 18),
              label: const Text('EEG bağlantısını kontrol et'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Diğer sayfalara sol üstteki menüden ulaşabilirsiniz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.hint(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep {
  const _FlowStep({
    required this.number,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String number;
  final String title;
  final String detail;
  final IconData icon;
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final _FlowStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.softPrimary(context),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              step.number,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(step.icon, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary(context),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
