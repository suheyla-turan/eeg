import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/text_content.dart';
import '../providers/eeg_provider.dart';
import '../providers/experiment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import 'experiment_result_screen.dart';

/// Okuma deneyi — metin gösterimi sırasında EEG kaydı devam eder.
class ReadingExperimentScreen extends StatefulWidget {
  const ReadingExperimentScreen({
    super.key,
    this.continueExistingSession = false,
    this.returnResultToCaller = false,
    this.autoDuration,
  });

  /// Reels / Flow sonrası geçişte true: oturum yeniden başlatılmaz.
  final bool continueExistingSession;

  /// true ise tamamlayıp dialog göstermez; çağırana geri döner.
  final bool returnResultToCaller;

  /// Verilirse süre dolunca otomatik biter.
  final Duration? autoDuration;

  @override
  State<ReadingExperimentScreen> createState() =>
      _ReadingExperimentScreenState();
}

class _ReadingExperimentScreenState extends State<ReadingExperimentScreen> {
  Timer? _eegTimer;
  Timer? _uiTimer;
  Timer? _autoTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  TextContent? _text;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _eegTimer?.cancel();
    _uiTimer?.cancel();
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<ExperimentProvider>();
    final eeg = context.read<EegProvider>();
    try {
      final text = await provider.resolveReadingText();
      if (!mounted) return;

      if (!widget.continueExistingSession && !provider.isRunning) {
        if (!eeg.canStartExperiment) {
          setState(() {
            _loading = false;
            _error =
                'EEG cihazı bağlı değil (durum: ${eeg.connectionLabel}). '
                'Cihazı bağlayıp tekrar deneyin.';
          });
          return;
        }
        await provider.startSession(initialPhase: 'text');
        if (provider.errorMessage != null) {
          setState(() {
            _loading = false;
            _error = provider.errorMessage;
          });
          return;
        }
      } else if (provider.isRunning) {
        provider.enterReadingPhase();
      }

      if (!mounted) return;
      setState(() {
        _text = text;
        _loading = false;
        _error = text == null
            ? 'Okuma metni bulunamadı. lib/data/local_texts.dart listesini kontrol edin.'
            : null;
        _startedAt = DateTime.now();
      });

      if (provider.isRunning) {
        _startTickers();
        final auto = widget.autoDuration;
        if (auto != null) {
          _autoTimer?.cancel();
          _autoTimer = Timer(auto, () {
            if (mounted) _complete();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startTickers() {
    _eegTimer?.cancel();
    _eegTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      await context.read<ExperimentProvider>().tickCapture();
    });

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
      });
    });
  }

  Future<void> _complete() async {
    _eegTimer?.cancel();
    _uiTimer?.cancel();
    _autoTimer?.cancel();
    final provider = context.read<ExperimentProvider>();

    if (widget.returnResultToCaller) {
      // Flow ekranı complete/upload yapacak — burada yalnızca pop.
      if (mounted) Navigator.of(context).pop();
      return;
    }

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

    final result = provider.lastResult;
    if (result != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExperimentResultScreen(
            result: result,
            experiment: provider.experiment,
            participant: provider.participant,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deney tamamlandı'),
        content: Text(
          'Okuma aşaması bitti.\n'
          'EEG örnekleri: ${provider.sampleCount}\n'
          'Video izleme kaydı: ${provider.watchEvents.length}\n'
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExperimentProvider>();
    final completing = provider.phase == ExperimentPhase.completing;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Reading Experiment'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: completing ? null : _complete,
                            child: const Text('Deneyi Bitir'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      SectionCard(
                        title: _text!.title,
                        subtitle:
                            '${_text!.difficulty} · ~${_text!.estimatedDuration} sn',
                        right: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_elapsed),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        child: Text(
                          _text!.content,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.55,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      SectionCard(
                        title: 'EEG Kaydı',
                        subtitle: widget.continueExistingSession
                            ? 'Video aşamasından kesintisiz devam ediyor.'
                            : 'Okuma sırasında örnekler toplanıyor.',
                        child: Text(
                          'Örnek sayısı: ${provider.sampleCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: completing ? null : _complete,
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
                          completing
                              ? 'Yükleniyor…'
                              : 'Okumayı Bitir ve Yükle',
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
