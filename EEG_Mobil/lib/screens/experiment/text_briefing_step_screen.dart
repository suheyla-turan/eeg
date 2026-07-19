import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class TextBriefingStepScreen extends StatefulWidget {
  const TextBriefingStepScreen({super.key});

  @override
  State<TextBriefingStepScreen> createState() => _TextBriefingStepScreenState();
}

class _TextBriefingStepScreenState extends State<TextBriefingStepScreen> {
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
        _ready();
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

  void _ready() {
    _timer?.cancel();
    context.read<ExperimentProvider>().manager.proceedFromTextBriefing();
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Metin Bilgilendirme',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    'Birazdan yaklaşık 10 dakika sürecek bir metin okuyacaksınız.\n\n'
                    'Lütfen metni dikkatlice okuyunuz.\n\n'
                    'Okuma boyunca EEG kaydı devam edecektir.',
                    style: TextStyle(
                      fontSize: 17,
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
              onReady: _ready,
            ),
          ],
        ),
      ),
    );
  }
}
