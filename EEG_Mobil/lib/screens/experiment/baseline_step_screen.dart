import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_scaffold.dart';

class BaselineStepScreen extends StatefulWidget {
  const BaselineStepScreen({super.key});

  @override
  State<BaselineStepScreen> createState() => _BaselineStepScreenState();
}

class _BaselineStepScreenState extends State<BaselineStepScreen> {
  Timer? _countdown;
  int _secondsLeft = ExperimentManager.baselineDuration.inSeconds;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final manager = context.read<ExperimentProvider>().manager;
    final ok = await manager.startBaselineRecording();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _starting = false;
        _error = manager.errorMessage ?? 'Baseline başlatılamadı';
      });
      return;
    }

    setState(() => _starting = false);
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _countdown?.cancel();
        manager.onBaselineFinished();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sampleCount = context.watch<ExperimentProvider>().sampleCount;

    if (_error != null) {
      return ExperimentScaffold(
        title: 'Baseline',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
    }

    return ExperimentScaffold(
      showAppBar: false,
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _starting ? 'Hazırlanıyor…' : 'Lütfen + işaretine bakın',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w300,
                    color: Colors.black,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_starting)
                  Text(
                    '$_secondsLeft sn',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 16,
            child: Text(
              'EEG $sampleCount',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
