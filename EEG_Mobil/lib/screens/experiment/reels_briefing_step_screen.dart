import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/section_card.dart';

class ReelsBriefingStepScreen extends StatefulWidget {
  const ReelsBriefingStepScreen({super.key});

  @override
  State<ReelsBriefingStepScreen> createState() =>
      _ReelsBriefingStepScreenState();
}

class _ReelsBriefingStepScreenState extends State<ReelsBriefingStepScreen> {
  late int _secondsLeft;
  Timer? _timer;
  bool _proceeding = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = ExperimentManager.briefingCountdown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        unawaited(_ready());
        return;
      }
      setState(() => _secondsLeft--);
    });
    // Bilgilendirme süresi boyunca ilk videoları arka planda hazırla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<ExperimentProvider>().manager.prepareReelsWarmup(),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ready() async {
    if (_proceeding) return;
    _proceeding = true;
    _timer?.cancel();
    final manager = context.read<ExperimentProvider>().manager;
    await manager.proceedFromReelsBriefing();
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Reels Bilgilendirme',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SectionCard(
                  title: 'Video aşaması',
                  icon: Icons.smart_display_outlined,
                  child: Text(
                    'Birazdan sosyal medya benzeri kısa videolar izleyeceksiniz.\n\n'
                    'Videolar arasında yukarı ve aşağı kaydırarak geçiş yapabilirsiniz.\n\n'
                    'Videoları doğal kullanım alışkanlığınıza göre izleyiniz.\n\n'
                    'EEG kaydı deney boyunca devam edecektir.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                          color: AppColors.foreground(context),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BriefingActions(
              secondsLeft: _secondsLeft,
              onReady: () => unawaited(_ready()),
            ),
          ],
        ),
      ),
    );
  }
}
