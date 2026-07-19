import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/text_content.dart';
import '../../models/text_quiz_question.dart';
import '../../models/text_quiz_response.dart';
import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/demo_skip_button.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/mood_question_panel.dart';
import '../../widgets/section_card.dart';

enum _ReadingPhase { reading, quiz, mood }

class TextReadingStepScreen extends StatefulWidget {
  const TextReadingStepScreen({super.key});

  @override
  State<TextReadingStepScreen> createState() => _TextReadingStepScreenState();
}

class _TextReadingStepScreenState extends State<TextReadingStepScreen> {
  static const _choiceLabels = ['A', 'B', 'C', 'D'];

  Timer? _uiTimer;
  Timer? _experimentTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  List<TextContent> _texts = [];
  int _textIndex = 0;
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  bool _sessionTimedOut = false;
  /// Tek metin oturumunda içerik bitince süre dolana kadar bekleniyor.
  bool _awaitingSessionEnd = false;

  _ReadingPhase _phase = _ReadingPhase.reading;
  int _quizIndex = 0;
  final Map<String, int> _selectedAnswers = {};

  TextContent? get _text =>
      _texts.isEmpty ? null : _texts[_textIndex % _texts.length];

  List<TextQuizQuestion> get _questions => _text?.questions ?? const [];

  bool get _timeUp =>
      _sessionTimedOut || _elapsed >= ExperimentManager.textDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _experimentTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final manager = context.read<ExperimentProvider>().manager;
    try {
      final texts = await manager.resolveReadingTexts();
      if (!mounted) return;

      setState(() {
        _texts = texts;
        _loading = false;
        _error = texts.isEmpty
            ? 'Okuma metni bulunamadı. CMS\'den aktif metin ekleyin.'
            : null;
        _startedAt = DateTime.now();
      });

      if (texts.isEmpty) return;

      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() {
          _elapsed = DateTime.now().difference(_startedAt!);
        });
      });

      _experimentTimer = Timer(ExperimentManager.textDuration, _onSessionTimeUp);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 10 dk dolunca duygu sorusuna geç (reels ile aynı mantık).
  void _onSessionTimeUp() {
    if (!mounted || _phase == _ReadingPhase.mood) return;
    _uiTimer?.cancel();
    _experimentTimer?.cancel();
    setState(() {
      _sessionTimedOut = true;
      _elapsed = ExperimentManager.textDuration;
      _phase = _ReadingPhase.mood;
    });
  }

  void _onReadingFinished() {
    if (_questions.isEmpty) {
      _goNextTextOrMood();
      return;
    }
    setState(() {
      _phase = _ReadingPhase.quiz;
      _quizIndex = 0;
    });
  }

  /// Demo: metin / test / duygu aşamasını atlayıp analize geçer.
  Future<void> _demoSkipText() async {
    if (_submitting) return;
    _uiTimer?.cancel();
    _experimentTimer?.cancel();
    setState(() => _submitting = true);
    final manager = context.read<ExperimentProvider>().manager;
    final text = _text;
    if (text != null) {
      await manager.saveQuizResponse(
        textId: text.textId,
        answers: const [],
        moodOptions: const ['Nötr'],
      );
    }
    if (!mounted) return;
    await manager.finishAndAnalyze();
  }

  void _selectAnswer(int choiceIndex) {
    final q = _questions[_quizIndex];
    setState(() => _selectedAnswers[q.questionId] = choiceIndex);
  }

  Future<void> _nextQuiz() async {
    final q = _questions[_quizIndex];
    if (!_selectedAnswers.containsKey(q.questionId)) return;

    if (_quizIndex < _questions.length - 1) {
      setState(() => _quizIndex++);
      return;
    }

    // Süre dolduysa cevapları duygu adımında birlikte kaydet.
    if (_timeUp || _texts.isEmpty) {
      _uiTimer?.cancel();
      _experimentTimer?.cancel();
      setState(() => _phase = _ReadingPhase.mood);
      return;
    }

    await _persistCurrentQuizAnswers(moodOptions: const []);
    if (!mounted) return;
    _goNextTextOrMood();
  }

  /// Süre dolmadıysa sonraki metne geç; dolduysa duygu sorusu.
  void _goNextTextOrMood() {
    if (_timeUp || _texts.isEmpty) {
      _uiTimer?.cancel();
      _experimentTimer?.cancel();
      setState(() => _phase = _ReadingPhase.mood);
      return;
    }

    // Tek metin: tekrar quiz yok — 10 dk dolunca duygu sorulur.
    if (_texts.length <= 1) {
      setState(() {
        _awaitingSessionEnd = true;
        _quizIndex = 0;
        _selectedAnswers.clear();
        _phase = _ReadingPhase.reading;
      });
      return;
    }

    setState(() {
      _textIndex = (_textIndex + 1) % _texts.length;
      _quizIndex = 0;
      _selectedAnswers.clear();
      _phase = _ReadingPhase.reading;
    });
  }

  Future<void> _persistCurrentQuizAnswers({
    required List<String> moodOptions,
    String? moodOtherText,
  }) async {
    final text = _text;
    if (text == null) return;

    final answers = <TextQuizAnswer>[];
    for (final q in text.questions) {
      final selected = _selectedAnswers[q.questionId];
      if (selected == null) continue;
      answers.add(
        TextQuizAnswer(
          questionId: q.questionId,
          prompt: q.prompt,
          selectedIndex: selected,
          selectedLabel: q.choices[selected],
          correctIndex: q.correctIndex,
          isCorrect: selected == q.correctIndex,
        ),
      );
    }

    // Ara metinlerde sadece test cevabı; duygu yalnızca oturum sonunda.
    if (answers.isEmpty && moodOptions.isEmpty) return;

    await context.read<ExperimentProvider>().manager.saveQuizResponse(
          textId: text.textId,
          answers: answers,
          moodOptions: moodOptions,
          moodOtherText: moodOtherText,
        );
  }

  Future<void> _submitMoodAndFinish(
    List<String> moodOptions,
    String? moodOtherText,
  ) async {
    setState(() => _submitting = true);
    final manager = context.read<ExperimentProvider>().manager;

    await _persistCurrentQuizAnswers(
      moodOptions: moodOptions,
      moodOtherText: moodOtherText,
    );

    if (!mounted) return;
    await manager.finishAndAnalyze();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatRemaining() {
    final left = ExperimentManager.textDuration - _elapsed;
    if (left.isNegative || left == Duration.zero) return '00:00';
    return _format(left);
  }

  @override
  Widget build(BuildContext context) {
    final sampleCount = context.watch<ExperimentProvider>().sampleCount;
    final title = switch (_phase) {
      _ReadingPhase.reading => 'Metin Deneyi',
      _ReadingPhase.quiz => 'Metin Testi',
      _ReadingPhase.mood => 'Nasıl Hissediyorsun?',
    };

    return ExperimentScaffold(
      title: title,
      floatingActionButton: _loading || _error != null
          ? null
          : DemoSkipButton(
              label: 'Metni Geç',
              onPressed: _submitting ? null : _demoSkipText,
            ),
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
              : switch (_phase) {
                  _ReadingPhase.reading =>
                    _buildReading(context, sampleCount),
                  _ReadingPhase.quiz => _buildQuiz(context),
                  _ReadingPhase.mood => MoodQuestionPanel(
                      subtitle:
                          '10 dakikalık metin oturumu bitti. Şu anki duygunuzu '
                          'seçin — birden fazla duygu seçebilirsiniz. İsterseniz '
                          '“Diğer” ile kendi duygunuzu da yazabilirsiniz.',
                      submitLabel: 'Devam Et',
                      submitting: _submitting,
                      onSubmit: _submitMoodAndFinish,
                    ),
                },
    );
  }

  Widget _buildReading(BuildContext context, int sampleCount) {
    final text = _text!;
    final textOrdinal = (_textIndex % _texts.length) + 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              _InfoChip(label: 'Geçen', value: _format(_elapsed)),
              const SizedBox(width: 8),
              _InfoChip(label: 'Kalan', value: _formatRemaining()),
              if (_texts.length > 1) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'Metin',
                  value: '$textOrdinal/${_texts.length}',
                ),
              ],
              const Spacer(),
              Text(
                'EEG $sampleCount',
                style: TextStyle(
                  color: AppColors.hint(context),
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
                  text.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (_questions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Okuma bitince ${_questions.length} soruluk test gelecek.',
                    style: TextStyle(
                      color: AppColors.secondary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Duygu sorusu yalnızca 10 dakikalık oturum bitince sorulur.',
                  style: TextStyle(
                    color: AppColors.hint(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  text.content,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.65,
                    color: AppColors.foreground(context),
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
              if (_awaitingSessionEnd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Bu metin bitti. Duygu sorusu 10 dakikalık süre '
                    'dolunca sorulacak (kalan: ${_formatRemaining()}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.hint(context),
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _awaitingSessionEnd ? null : _onReadingFinished,
                child: Text(
                  _awaitingSessionEnd
                      ? 'Süre bekleniyor…'
                      : (_questions.isEmpty
                          ? (_texts.length > 1
                              ? 'Sonraki Metne Geç'
                              : 'Okumayı Bitirdim')
                          : 'Okumayı Bitirdim — Teste Geç'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final q = _questions[_quizIndex];
    final selected = _selectedAnswers[q.questionId];
    final scheme = Theme.of(context).colorScheme;
    final isLastQuestion = _quizIndex >= _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Soru ${_quizIndex + 1} / ${_questions.length}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_quizIndex + 1) / _questions.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: SectionCard(
                title: q.prompt,
                icon: Icons.help_outline,
                child: Column(
                  children: [
                    for (var i = 0; i < q.choices.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ChoiceTile(
                        label: _choiceLabels[i],
                        text: q.choices[i],
                        selected: selected == i,
                        onTap: () => _selectAnswer(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: selected == null ? null : _nextQuiz,
            child: Text(
              isLastQuestion
                  ? (_timeUp
                      ? 'Testi Bitir'
                      : (_texts.length > 1
                          ? 'Sonraki Metne Geç'
                          : 'Testi Bitir'))
                  : 'Sonraki Soru',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? AppColors.softPrimary(context)
          : AppColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.line(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : AppColors.muted(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? scheme.onPrimary
                        : AppColors.foreground(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 22),
            ],
          ),
        ),
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
        color: AppColors.softPrimary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondary(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
