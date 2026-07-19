import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

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

  void _continue() {
    _timer?.cancel();
    context.read<ExperimentProvider>().manager.proceedFromBriefing();
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Deney Bilgilendirme',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deney Hakkında',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Bu deney sırasında EEG cihazınız takılı kalacaktır.\n\n'
                    'Sırasıyla:\n'
                    '• Kısa bir baseline ölçümü\n'
                    '• Yaklaşık 10 dakika sosyal medya benzeri kısa videolar\n'
                    '• Yaklaşık 10 dakika metin okuma\n\n'
                    'Lütfen talimatları dikkatle izleyin ve doğal davranın.\n\n'
                    'Deney boyunca telefonunuzun ekranı açık kalacak ve '
                    'geri tuşu kullanılamayacaktır.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
