import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_messenger.dart';
import '../core/app_page_route.dart';
import '../models/experiment_status.dart';
import '../providers/experiment_provider.dart';
import '../providers/recovery_provider.dart';
import '../screens/experiment/experiment_flow_screen.dart';
import '../screens/experiment_session_screen.dart';
import '../screens/reading_experiment_screen.dart';

/// "Yarım kalan deney bulundu" diyaloğu.
Future<void> showRecoveryDialogIfNeeded(BuildContext context) async {
  final recovery = context.read<RecoveryProvider>();
  if (recovery.dialogShown || !recovery.hasRecoverableSession) return;
  if (!context.mounted) return;

  recovery.markDialogShown();

  final exp = recovery.incompleteExperiment;
  final participant = recovery.incompleteParticipant;
  final checkpoint = recovery.checkpoint;
  final sampleCount = checkpoint?.sampleCount ?? 0;
  final dateFmt = DateFormat('d MMM yyyy HH:mm', 'tr');
  final savedAt = checkpoint?.savedAt ?? exp?.createdAt;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(
          Icons.restore,
          color: Theme.of(ctx).colorScheme.primary,
          size: 36,
        ),
        title: const Text('Yarım kalan deney bulundu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beklenmeyen bir kapanma sonrası kurtarılabilir oturum tespit edildi.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (participant != null)
              _MetaRow(
                label: 'Katılımcı',
                value: '${participant.firstName} ${participant.lastName}',
              ),
            if (exp != null) ...[
              _MetaRow(
                label: 'Durum',
                value: ExperimentStatus.labelTr(exp.status),
              ),
              _MetaRow(
                label: 'Tür',
                value: exp.experimentType,
              ),
            ],
            if (savedAt != null)
              _MetaRow(
                label: 'Kayıt',
                value: dateFmt.format(savedAt),
              ),
            _MetaRow(
              label: 'EEG örnekleri',
              value: '$sampleCount',
            ),
            const SizedBox(height: 8),
            Text(
              checkpoint != null
                  ? 'Devam ederseniz kayıtlı EEG verileri korunur.'
                  : 'Yerel EEG checkpoint bulunamadı; yalnızca kaydı sonlandırabilirsiniz.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('end'),
            child: const Text('Sonlandır'),
          ),
          FilledButton(
            onPressed: checkpoint == null
                ? null
                : () => Navigator.of(ctx).pop('continue'),
            child: const Text('Devam Et'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;

  if (result == 'end') {
    await recovery.discardAsCancelled();
    AppMessenger.info('Yarım kalan deney sonlandırıldı (İptal Edildi).');
    return;
  }

  if (result == 'continue' && checkpoint != null) {
    final expProvider = context.read<ExperimentProvider>();
    final ok = await expProvider.resumeFromCheckpoint(checkpoint);
    if (!context.mounted) return;

    if (!ok) {
      AppMessenger.error(
        expProvider.errorMessage ?? 'Devam edilemedi',
      );
      return;
    }

    recovery.clearLocalState();
    AppMessenger.success('Deney devam ettiriliyor…');

    final type = expProvider.experimentType;
    final Widget page;
    if (type == 'live_eeg') {
      page = const ExperimentSessionScreen();
    } else if (type == 'text') {
      page = const ReadingExperimentScreen(continueExistingSession: true);
    } else {
      page = const ExperimentFlowScreen();
    }

    await Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.sharedAxisX,
        builder: (_) => page,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
