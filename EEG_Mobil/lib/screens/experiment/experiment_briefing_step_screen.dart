import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/section_card.dart';

class ExperimentBriefingStepScreen extends StatefulWidget {
  const ExperimentBriefingStepScreen({super.key});

  @override
  State<ExperimentBriefingStepScreen> createState() =>
      _ExperimentBriefingStepScreenState();
}

class _ExperimentBriefingStepScreenState
    extends State<ExperimentBriefingStepScreen> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = ExperimentManager.briefingCountdown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _continue();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    _timer?.cancel();
    final manager = context.read<ExperimentProvider>().manager;
    final ok = await manager.proceedFromBriefing();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(manager.errorMessage ?? 'Kayıt başlatılamadı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Hazırlık',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deney Hakkında',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kısa bir bilgilendirme. Hazır olduğunuzda devam edin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondary(context),
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: SectionCard(
                  title: 'Protokol',
                  icon: Icons.info_outline,
                  child: Text(
                    'Bu deney sırasında EEG cihazınız takılı kalacaktır.\n\n'
                    'Sırasıyla:\n'
                    '• Yaklaşık 10 dakika sosyal medya benzeri kısa videolar\n'
                    '• Yaklaşık 10 dakika metin okuma\n\n'
                    'Lütfen talimatları dikkatle izleyin ve doğal davranın.\n\n'
                    'Deney boyunca telefonunuzun ekranı açık kalacak ve '
                    'geri tuşu kullanılamayacaktır.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BriefingActions(
              secondsLeft: _secondsLeft,
              onReady: _continue,
              readyLabel: 'Devam Et',
            ),
          ],
        ),
      ),
    );
  }
}
