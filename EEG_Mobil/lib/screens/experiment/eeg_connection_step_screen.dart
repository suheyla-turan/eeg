import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/eeg_provider.dart';
import '../../providers/experiment_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class EegConnectionStepScreen extends StatelessWidget {
  const EegConnectionStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eeg = context.watch<EegProvider>();
    final manager = context.read<ExperimentProvider>().manager;
    final connected = eeg.canStartExperiment;

    return ExperimentScaffold(
      title: 'EEG Bağlantısı',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cihaz Bağlantısı',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              eeg.isDemoMode
                  ? 'Demo modu açık — sahte EEG ile deneye devam edebilirsiniz.'
                  : 'Deneye devam etmek için EEG cihazının bağlı olması gerekir.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    eeg.isDemoMode
                        ? Icons.science_outlined
                        : connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                    size: 64,
                    color: connected
                        ? (eeg.isDemoMode
                            ? AppColors.primary
                            : AppColors.success)
                        : AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    connected
                        ? (eeg.isDemoMode ? 'Bağlı (Demo)' : 'Bağlı')
                        : eeg.connectionLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: connected
                          ? (eeg.isDemoMode
                              ? AppColors.primary
                              : AppColors.success)
                          : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    connected
                        ? (eeg.isDemoMode
                            ? 'Sahte sinyal akıyor. Devam edebilirsiniz.'
                            : 'EEG sinyali alınabiliyor. Devam edebilirsiniz.')
                        : 'Cihazı takın ve bağlantı kurulana kadar bekleyin '
                            '(veya Ayarlar → Demo modu).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (eeg.live.batteryPercent > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Batarya: ${eeg.live.batteryPercent}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => eeg.reconnect(),
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Bağlan'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: connected
                  ? () => manager.proceedFromEegConnection()
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}
