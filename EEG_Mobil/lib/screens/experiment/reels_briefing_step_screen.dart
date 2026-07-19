import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class ReelsBriefingStepScreen extends StatefulWidget {
  const ReelsBriefingStepScreen({super.key});

  @override
  State<ReelsBriefingStepScreen> createState() =>
      _ReelsBriefingStepScreenState();
}

class _ReelsBriefingStepScreenState extends State<ReelsBriefingStepScreen> {
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
    context.read<ExperimentProvider>().manager.proceedFromReelsBriefing();
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Reels Bilgilendirme',
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
                    'Birazdan sosyal medya benzeri kısa videolar izleyeceksiniz.\n\n'
                    'Videolar arasında yukarı ve aşağı kaydırarak geçiş yapabilirsiniz.\n\n'
                    'Videoları doğal kullanım alışkanlığınıza göre izleyiniz.\n\n'
                    'EEG kaydı deney boyunca devam edecektir.',
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
