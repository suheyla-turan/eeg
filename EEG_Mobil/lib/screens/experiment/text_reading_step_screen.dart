import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/text_content.dart';
import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class TextReadingStepScreen extends StatefulWidget {
  const TextReadingStepScreen({super.key});

  @override
  State<TextReadingStepScreen> createState() => _TextReadingStepScreenState();
}

class _TextReadingStepScreenState extends State<TextReadingStepScreen> {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  TextContent? _text;
  bool _loading = true;
  String? _error;

  bool get _canFinish =>
      _elapsed >= ExperimentManager.textMinDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final manager = context.read<ExperimentProvider>().manager;
    try {
      final text = await manager.resolveReadingText();
      if (!mounted) return;

      setState(() {
        _text = text;
        _loading = false;
        _error = text == null
            ? 'Okuma metni bulunamadı. CMS\'den aktif metin ekleyin.'
            : null;
        _startedAt = DateTime.now();
      });

      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() {
          _elapsed = DateTime.now().difference(_startedAt!);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _finish() async {
    if (!_canFinish) return;
    _uiTimer?.cancel();
    await context.read<ExperimentProvider>().manager.finishAndAnalyze();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatRemaining() {
    final left = ExperimentManager.textMinDuration - _elapsed;
    if (left.isNegative || left == Duration.zero) return '00:00';
    return _format(left);
  }

  @override
  Widget build(BuildContext context) {
    final sampleCount = context.watch<ExperimentProvider>().sampleCount;

    return ExperimentScaffold(
      title: 'Metin Deneyi',
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
                          onPressed: () => context
                              .read<ExperimentProvider>()
                              .manager
                              .finishAndAnalyze(),
                          child: const Text('Analize Geç'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          _InfoChip(
                            label: 'Süre',
                            value: _format(_elapsed),
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            label: _canFinish ? 'Hazır' : 'Kalan min.',
                            value: _canFinish ? '✓' : _formatRemaining(),
                          ),
                          const Spacer(),
                          Text(
                            'EEG $sampleCount',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text!.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _text!.content,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.65,
                                color: AppColors.text,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_canFinish)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '“Okumayı Bitirdim” butonu 10 dakika sonra aktif olur.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          FilledButton(
                            onPressed: _canFinish ? _finish : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.border,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Okumayı Bitirdim'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
