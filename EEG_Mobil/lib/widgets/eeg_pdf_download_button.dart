import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_dependencies.dart';
import '../models/experiment_result.dart';
import '../models/participant.dart';
import '../services/eeg_pdf_export_service.dart';
import '../theme/app_colors.dart';

/// Ham EEG PDF indirme düğmesi (Reels + Metin, tek dosya).
class EegPdfDownloadButton extends StatefulWidget {
  const EegPdfDownloadButton({
    super.key,
    required this.result,
    this.participant,
    this.experimentDate,
    this.storagePath,
    this.localSamples,
    this.outlined = true,
  });

  final ExperimentResult result;
  final Participant? participant;
  final DateTime? experimentDate;
  final String? storagePath;

  /// Oturum sonu: Storage olmadan PDF için ham örnekler.
  final List<Map<String, dynamic>>? localSamples;
  final bool outlined;

  @override
  State<EegPdfDownloadButton> createState() => _EegPdfDownloadButtonState();
}

class _EegPdfDownloadButtonState extends State<EegPdfDownloadButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final deps = context.read<AppDependencies>();
      await EegPdfExportService.download(
        storage: deps.eegStorageRepository,
        experimentId: widget.result.experimentId,
        storagePath: widget.storagePath,
        participant: widget.participant,
        experimentDate: widget.experimentDate,
        localSamples: widget.localSamples,
      );
      if (!mounted) return;
      final name = EegPdfExportService.buildFileName(
        participant: widget.participant,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ham EEG PDF hazır: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 20),
              SizedBox(width: 8),
              Text('Ham EEG PDF İndir'),
            ],
          );

    if (widget.outlined) {
      return OutlinedButton(
        onPressed: _busy ? null : _onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: _busy ? null : _onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: child,
    );
  }
}
