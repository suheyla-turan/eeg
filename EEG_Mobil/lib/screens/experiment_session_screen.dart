import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/eeg_provider.dart';
import '../providers/experiment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class ExperimentSessionScreen extends StatefulWidget {
  const ExperimentSessionScreen({super.key});

  @override
  State<ExperimentSessionScreen> createState() =>
      _ExperimentSessionScreenState();
}

class _ExperimentSessionScreenState extends State<ExperimentSessionScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _startedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final provider = context.read<ExperimentProvider>();
      await provider.tickCapture();
      if (!mounted) return;
      setState(() {
        if (_startedAt != null) {
          _elapsed = DateTime.now().difference(_startedAt!);
        }
      });
    });
  }

  Future<void> _onStart() async {
    final eeg = context.read<EegProvider>();
    if (!eeg.canStartExperiment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'EEG cihazı bağlı değil (durum: ${eeg.connectionLabel}). '
            'Cihazı bağlayıp "Bağlı" olana kadar bekleyin.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final provider = context.read<ExperimentProvider>();
    await provider.startSession();
    if (!mounted) return;
    if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (provider.isRunning) _startTicker();
  }

  Future<void> _onComplete() async {
    _timer?.cancel();
    final provider = context.read<ExperimentProvider>();
    final ok = await provider.completeSession();
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Tamamlama başarısız'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deney tamamlandı'),
        content: Text(
          'EEG JSON Storage\'a yüklendi.\n'
          'Örnek: ${provider.sampleCount}\n'
          'Yol: ${provider.lastStoragePath ?? '-'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    provider.reset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExperimentProvider>();
    final eeg = context.watch<EegProvider>();
    final p = provider.participant;
    final exp = provider.experiment;
    final running = provider.isRunning;
    final completing = provider.phase == ExperimentPhase.completing;
    final eegReady = eeg.canStartExperiment;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text('Deney Oturumu'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SectionCard(
              title: p?.fullName ?? 'Katılımcı',
              subtitle: p == null
                  ? null
                  : '${p.age} yaş · ${p.gender} · ${p.occupation}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Experiment', exp?.experimentId ?? '-'),
                  _row('Tip', exp?.experimentType ?? '-'),
                  _row(
                    'Durum',
                    running
                        ? 'Kayıt sürüyor'
                        : completing
                            ? 'Yükleniyor…'
                            : 'Hazır',
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'EEG Bağlantısı',
              subtitle: 'Deney yalnızca cihaz "Bağlı" iken başlatılabilir',
              child: Row(
                children: [
                  StatusPill(
                    label: eeg.connectionLabel,
                    tone: eegReady ? StatusTone.success : StatusTone.danger,
                  ),
                  const Spacer(),
                  Text(
                    eegReady ? 'Hazır' : 'Bekleniyor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: eegReady ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Canlı Kayıt',
              subtitle:
                  'EEG örnekleri geçici bellekte tutulur; Firestore\'a yazılmaz.',
              child: Row(
                children: [
                  Expanded(
                    child: _metric(
                      'Süre',
                      _formatDuration(_elapsed),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metric(
                      'Örnek',
                      '${provider.sampleCount}',
                    ),
                  ),
                ],
              ),
            ),
            if (!eegReady && !running)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF0D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'EEG cihazı bağlı değil (durum: ${eeg.connectionLabel}). '
                  'Headset\'i takın ve bağlantı "Bağlı" olana kadar bekleyin.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.warning,
                    height: 1.35,
                  ),
                ),
              ),
            if (provider.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E4E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                  ),
                ),
              ),
            if (!running && !completing)
              FilledButton.icon(
                onPressed: eegReady ? _onStart : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  eegReady ? 'Deneyi Başlat' : 'EEG Bağlantısı Gerekli',
                ),
              ),
            if (running)
              FilledButton.icon(
                onPressed: completing ? null : _onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: completing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.stop),
                label: Text(
                  completing ? 'JSON yükleniyor…' : 'Deneyi Bitir ve Yükle',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
