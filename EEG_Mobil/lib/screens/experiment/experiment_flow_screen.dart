import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/experiment_step.dart';
import '../../providers/experiment_provider.dart';
import '../../theme/app_colors.dart';
import 'analysis_step_screen.dart';
import 'baseline_step_screen.dart';
import 'eeg_connection_step_screen.dart';
import 'experiment_briefing_step_screen.dart';
import 'experiment_results_step_screen.dart';
import 'reels_briefing_step_screen.dart';
import 'reels_completed_step_screen.dart';
import 'reels_step_screen.dart';
import 'text_briefing_step_screen.dart';
import 'text_reading_step_screen.dart';

/// ExperimentManager adımlarına göre ekran değiştiren akış kabuğu.
class ExperimentFlowScreen extends StatefulWidget {
  const ExperimentFlowScreen({super.key});

  @override
  State<ExperimentFlowScreen> createState() => _ExperimentFlowScreenState();
}

class _ExperimentFlowScreenState extends State<ExperimentFlowScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ExperimentProvider>();
      // Checkpoint devamında kayıt zaten açık — beginFlow çağırma.
      if (!provider.manager.isRecording &&
          provider.manager.step == ExperimentStep.participantInfo) {
        provider.startFullExperimentFlow();
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _exitToHome() async {
    final provider = context.read<ExperimentProvider>();
    await provider.reset();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExperimentProvider>();
    final step = provider.currentStep;

    return PopScope(
      canPop: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(step),
          child: _buildStep(step, provider),
        ),
      ),
    );
  }

  Widget _buildStep(ExperimentStep step, ExperimentProvider provider) {
    switch (step) {
      case ExperimentStep.participantInfo:
      case ExperimentStep.eegConnection:
        return const EegConnectionStepScreen();
      case ExperimentStep.experimentBriefing:
        return const ExperimentBriefingStepScreen();
      case ExperimentStep.baseline:
        return const BaselineStepScreen();
      case ExperimentStep.reelsBriefing:
        return const ReelsBriefingStepScreen();
      case ExperimentStep.reels:
        return const ReelsStepScreen();
      case ExperimentStep.reelsCompleted:
        return const ReelsCompletedStepScreen();
      case ExperimentStep.textBriefing:
        return const TextBriefingStepScreen();
      case ExperimentStep.textReading:
        return const TextReadingStepScreen();
      case ExperimentStep.analyzing:
        return const AnalysisStepScreen();
      case ExperimentStep.results:
        return ExperimentResultsStepScreen(onDone: _exitToHome);
      case ExperimentStep.cancelled:
        if (provider.lastResult != null) {
          return ExperimentResultsStepScreen(onDone: _exitToHome);
        }
        return _CancelledStep(onDone: _exitToHome);
    }
  }
}

class _CancelledStep extends StatelessWidget {
  const _CancelledStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExperimentProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.cancel_outlined,
                size: 72,
                color: AppColors.danger.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 20),
              Text(
                'Deney İptal Edildi',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'status = cancelled\n'
                'O ana kadar alınan EEG verileri kaydedildi.\n'
                'Örnek: ${provider.sampleCount}\n'
                'Yol: ${provider.lastStoragePath ?? '-'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
