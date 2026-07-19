import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class ReelsCompletedStepScreen extends StatefulWidget {
  const ReelsCompletedStepScreen({super.key});

  @override
  State<ReelsCompletedStepScreen> createState() =>
      _ReelsCompletedStepScreenState();
}

class _ReelsCompletedStepScreenState extends State<ReelsCompletedStepScreen> {
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
        _continue();
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

  void _continue() {
    _timer?.cancel();
    context.read<ExperimentProvider>().manager.proceedFromReelsCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Reels Tamamlandı',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: AppColors.success.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 20),
            Text(
              'Video aşaması tamamlandı',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bir sonraki aşamaya geçmek için bekleyin veya Devam Et’e basın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondary(context),
                height: 1.45,
              ),
            ),
            const Spacer(),
            BriefingActions(
              secondsLeft: _secondsLeft,
              onReady: _continue,
              readyLabel: 'Devam Et',
            ),
          ],
        ),
      ),
    );
  }
}
