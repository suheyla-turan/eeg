import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class AnalysisStepScreen extends StatelessWidget {
  const AnalysisStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.watch<ExperimentProvider>().manager.errorMessage;

    return ExperimentScaffold(
      title: 'Analiz',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error == null) ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                const SizedBox(height: 28),
                Text(
                  'Veriler Analiz Ediliyor',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'EEG verileri yükleniyor ve özet skorlar hesaplanıyor…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondary(context),
                    height: 1.4,
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline,
                    size: 56, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context
                      .read<ExperimentProvider>()
                      .manager
                      .finishAndAnalyze(),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
