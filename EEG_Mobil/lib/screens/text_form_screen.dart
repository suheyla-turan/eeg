import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/text_content.dart';
import '../models/text_quiz_question.dart';
import '../providers/text_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

class TextFormScreen extends StatefulWidget {
  const TextFormScreen({super.key, this.existing});

  final TextContent? existing;

  @override
  State<TextFormScreen> createState() => _TextFormScreenState();
}

class _TextFormScreenState extends State<TextFormScreen> {
  static const _choiceLabels = ['A', 'B', 'C', 'D'];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final List<_QuestionDraft> _questions = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _content.text = e.content;
      for (final q in e.questions) {
        _questions.add(_QuestionDraft.fromQuestion(q));
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionDraft.empty()));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  List<TextQuizQuestion> _buildQuestions() {
    final result = <TextQuizQuestion>[];
    for (var i = 0; i < _questions.length; i++) {
      final d = _questions[i];
      final prompt = d.prompt.text.trim();
      if (prompt.isEmpty) continue;
      final choices = d.choices.map((c) => c.text.trim()).toList();
      if (choices.any((c) => c.isEmpty)) continue;
      if (d.correctIndex == null) continue;
      result.add(
        TextQuizQuestion(
          questionId: d.questionId.isNotEmpty
              ? d.questionId
              : 'q_${DateTime.now().microsecondsSinceEpoch}_$i',
          prompt: prompt,
          choices: choices,
          correctIndex: d.correctIndex!,
        ),
      );
    }
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    for (var i = 0; i < _questions.length; i++) {
      final d = _questions[i];
      final prompt = d.prompt.text.trim();
      final choices = d.choices.map((c) => c.text.trim()).toList();
      if (prompt.isEmpty && choices.every((c) => c.isEmpty)) continue;
      if (prompt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru ${i + 1}: soru metni zorunlu'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (choices.any((c) => c.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru ${i + 1}: dört şık da doldurulmalı'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (d.correctIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru ${i + 1}: doğru cevabı seçin'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    final provider = context.read<TextContentProvider>();
    final questions = _buildQuestions();

    if (_isEdit) {
      final ok = await provider.updateText(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          content: _content.text.trim(),
          questions: questions,
        ),
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Güncelleme başarısız'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    } else {
      final created = await provider.create(
        title: _title.text.trim(),
        content: _content.text.trim(),
        difficulty: '',
        estimatedDuration: 0,
        active: true,
        questions: questions,
      );
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Kayıt başarısız'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<TextContentProvider>().saving;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Metin Düzenle' : 'Metin Ekle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              SectionCard(
                title: 'Metin',
                icon: Icons.article_outlined,
                child: Column(
                  children: [
                    _field(_title, 'Başlık', required: true),
                    _field(_content, 'İçerik', required: true, maxLines: 10),
                  ],
                ),
              ),
              SectionCard(
                title: 'Test Soruları',
                subtitle: 'Her soru için 4 şık ve doğru cevap zorunludur',
                icon: Icons.quiz_outlined,
                right: IconButton(
                  tooltip: 'Soru ekle',
                  onPressed: _addQuestion,
                  icon: Icon(Icons.add_circle_outline, color: scheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_questions.isEmpty)
                      Text(
                        'Henüz soru yok. “Soru ekle” ile ekleyebilirsiniz.',
                        style: TextStyle(
                          color: AppColors.secondary(context),
                          height: 1.4,
                        ),
                      ),
                    for (var i = 0; i < _questions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _QuestionEditor(
                        index: i,
                        draft: _questions[i],
                        choiceLabels: _choiceLabels,
                        onRemove: () => _removeQuestion(i),
                        onCorrectChanged: (v) {
                          setState(() => _questions[i].correctIndex = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Soru Ekle'),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: _decoration(label),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null
            : null,
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.muted(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line(context)),
      ),
    );
  }
}

class _QuestionDraft {
  _QuestionDraft({
    required this.questionId,
    required this.prompt,
    required this.choices,
    this.correctIndex,
  });

  factory _QuestionDraft.empty() => _QuestionDraft(
        questionId: '',
        prompt: TextEditingController(),
        choices: List.generate(4, (_) => TextEditingController()),
      );

  factory _QuestionDraft.fromQuestion(TextQuizQuestion q) {
    final choices = List.generate(4, (i) {
      final text = i < q.choices.length ? q.choices[i] : '';
      return TextEditingController(text: text);
    });
    return _QuestionDraft(
      questionId: q.questionId,
      prompt: TextEditingController(text: q.prompt),
      choices: choices,
      correctIndex: q.correctIndex,
    );
  }

  final String questionId;
  final TextEditingController prompt;
  final List<TextEditingController> choices;
  int? correctIndex;

  void dispose() {
    prompt.dispose();
    for (final c in choices) {
      c.dispose();
    }
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.draft,
    required this.choiceLabels,
    required this.onRemove,
    required this.onCorrectChanged,
  });

  final int index;
  final _QuestionDraft draft;
  final List<String> choiceLabels;
  final VoidCallback onRemove;
  final ValueChanged<int> onCorrectChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Soru ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
          TextFormField(
            controller: draft.prompt,
            decoration: const InputDecoration(labelText: 'Soru metni'),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            TextFormField(
              controller: draft.choices[i],
              decoration: InputDecoration(
                labelText: 'Şık ${choiceLabels[i]}',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    choiceLabels[i],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 28),
              ),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: draft.correctIndex,
            decoration: const InputDecoration(
              labelText: 'Doğru cevap *',
              hintText: 'Doğru şıkkı seçin',
            ),
            items: [
              for (var i = 0; i < 4; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text('Şık ${choiceLabels[i]}'),
                ),
            ],
            validator: (v) => v == null ? 'Doğru cevabı seçin' : null,
            onChanged: (v) {
              if (v != null) onCorrectChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
