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
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/section_card.dart';

enum _ReadingPhase { reading, quiz, mood }

class TextReadingStepScreen extends StatefulWidget {
  const TextReadingStepScreen({super.key});

  @override
  State<TextReadingStepScreen> createState() => _TextReadingStepScreenState();
}

class _TextReadingStepScreenState extends State<TextReadingStepScreen> {
  static const _moodOptions = <String>[
    'Mutlu',
    'Sakin',
    'Nötr',
    'Yorgun',
    'Stresli',
    'Diğer',
  ];
  static const _choiceLabels = ['A', 'B', 'C', 'D'];

  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  TextContent? _text;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  _ReadingPhase _phase = _ReadingPhase.reading;
  int _quizIndex = 0;
  final Map<String, int> _selectedAnswers = {};
  String? _moodOption;
  final _moodOther = TextEditingController();

  bool get _canFinish => _elapsed >= ExperimentManager.textMinDuration;

  List<TextQuizQuestion> get _questions => _text?.questions ?? const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _moodOther.dispose();
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

  void _onReadingFinished() {
    if (!_canFinish) return;
    _uiTimer?.cancel();
    if (_questions.isEmpty) {
      setState(() => _phase = _ReadingPhase.mood);
      return;
    }
    setState(() {
      _phase = _ReadingPhase.quiz;
      _quizIndex = 0;
    });
  }

  void _selectAnswer(int choiceIndex) {
    final q = _questions[_quizIndex];
    setState(() => _selectedAnswers[q.questionId] = choiceIndex);
  }

  void _nextQuiz() {
    final q = _questions[_quizIndex];
    if (!_selectedAnswers.containsKey(q.questionId)) return;

    if (_quizIndex >= _questions.length - 1) {
      setState(() => _phase = _ReadingPhase.mood);
      return;
    }
    setState(() => _quizIndex++);
  }

  Future<void> _submitMoodAndFinish() async {
    if (_moodOption == null) return;
    if (_moodOption == 'Diğer' && _moodOther.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen nasıl hissettiğinizi yazın'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final manager = context.read<ExperimentProvider>().manager;
    final text = _text;

    final answers = <TextQuizAnswer>[];
    for (final q in _questions) {
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

    if (text != null) {
      await manager.saveQuizResponse(
        textId: text.textId,
        answers: answers,
        moodOption: _moodOption!,
        moodOtherText:
            _moodOption == 'Diğer' ? _moodOther.text.trim() : null,
      );
    }

    if (!mounted) return;
    await manager.finishAndAnalyze();
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
    final title = switch (_phase) {
      _ReadingPhase.reading => 'Metin Deneyi',
      _ReadingPhase.quiz => 'Metin Testi',
      _ReadingPhase.mood => 'Nasıl Hissediyorsun?',
    };

    return ExperimentScaffold(
      title: title,
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
                  _ReadingPhase.mood => _buildMood(context),
                },
    );
  }

  Widget _buildReading(BuildContext context, int sampleCount) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              _InfoChip(label: 'Süre', value: _format(_elapsed)),
              const SizedBox(width: 8),
              _InfoChip(
                label: _canFinish ? 'Hazır' : 'Kalan min.',
                value: _canFinish ? '✓' : _formatRemaining(),
              ),
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
                  _text!.title,
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
                const SizedBox(height: 20),
                Text(
                  _text!.content,
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
              if (!_canFinish)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '“Okumayı Bitirdim” butonu 10 dakika sonra aktif olur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.hint(context),
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _canFinish ? _onReadingFinished : null,
                child: Text(
                  _questions.isEmpty
                      ? 'Okumayı Bitirdim'
                      : 'Okumayı Bitirdim — Teste Geç',
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
              _quizIndex >= _questions.length - 1
                  ? 'Testi Bitir'
                  : 'Sonraki Soru',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMood(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nasıl hissediyorsun?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Metin ve testler bitti. Şu anki duygunuzu seçin.',
            style: TextStyle(
              color: AppColors.secondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView(
              children: [
                for (final option in _moodOptions) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ChoiceTile(
                      label: option == 'Diğer' ? '…' : option[0],
                      text: option,
                      selected: _moodOption == option,
                      onTap: () => setState(() => _moodOption = option),
                    ),
                  ),
                ],
                if (_moodOption == 'Diğer') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _moodOther,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nasıl hissettiğinizi yazın',
                      hintText: 'Kısaca belirtin…',
                    ),
                  ),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: _submitting || _moodOption == null
                ? null
                : _submitMoodAndFinish,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Devam Et'),
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
