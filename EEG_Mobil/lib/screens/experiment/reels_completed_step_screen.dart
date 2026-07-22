import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/experiment_provider.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/mood_question_panel.dart';

/// Video aşaması bitince duygu sorusu; cevaplanınca metin bilgilendirmesine geçer.
class ReelsCompletedStepScreen extends StatefulWidget {
  const ReelsCompletedStepScreen({super.key});

  @override
  State<ReelsCompletedStepScreen> createState() =>
      _ReelsCompletedStepScreenState();
}

class _ReelsCompletedStepScreenState extends State<ReelsCompletedStepScreen> {
  bool _submitting = false;

  Future<void> _onMoodSubmit(
    List<String> moodOptions,
    String? moodOtherText,
  ) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await context.read<ExperimentProvider>().manager.saveReelsMoodAndContinue(
          moodOptions: moodOptions,
          moodOtherText: moodOtherText,
        );
  }

  @override
  Widget build(BuildContext context) {
    return ExperimentScaffold(
      title: 'Nasıl Hissediyorsun?',
      child: MoodQuestionPanel(
        subtitle:
            'Video izleme bitti. Videoları izlerken veya hemen sonrasında '
            'nasıl hissettiğinizi seçin — birden fazla duygu seçebilirsiniz. '
            'İsterseniz “Diğer” ile kendi duygunuzu da yazabilirsiniz.',
        submitLabel: 'Devam Et',
        submitting: _submitting,
        onSubmit: _onMoodSubmit,
      ),
    );
  }
}
