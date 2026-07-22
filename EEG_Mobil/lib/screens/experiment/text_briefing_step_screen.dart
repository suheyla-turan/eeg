import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/section_card.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SectionCard(
                  title: 'Okuma aşaması',
                  icon: Icons.menu_book_outlined,
                  child: Text(
                    'Birazdan yaklaşık 10 dakika sürecek bir metin okuma '
                    'oturumu başlayacak.\n\n'
                    'Metinler ve soru-cevaplar aynı süreden düşer; süre '
                    'dolunca veya son test bitince (videodaki gibi) duygu '
                    'sorusu sorulur.\n\n'
                    'Okuma ve test boyunca EEG kaydı devam edecektir.',
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
              onReady: _ready,
            ),
          ],
        ),
      ),
    );
  }
}
