/// Metinle birlikte tanımlanan 4 şıklı test sorusu.
class TextQuizQuestion {
  final String questionId;
  final String prompt;
  final List<String> choices;
  final int correctIndex;

  const TextQuizQuestion({
    required this.questionId,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'prompt': prompt,
      'choices': choices,
      'correctIndex': correctIndex,
    };
  }

  factory TextQuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawChoices = map['choices'];
    final choices = rawChoices is List
        ? rawChoices.map((e) => e.toString()).toList()
        : <String>[];
    while (choices.length < 4) {
      choices.add('');
    }
    final correct = (map['correctIndex'] as num?)?.toInt() ?? 0;
    return TextQuizQuestion(
      questionId: map['questionId'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      choices: choices.take(4).toList(),
      correctIndex: correct.clamp(0, 3),
    );
  }

  TextQuizQuestion copyWith({
    String? questionId,
    String? prompt,
    List<String>? choices,
    int? correctIndex,
  }) {
    return TextQuizQuestion(
      questionId: questionId ?? this.questionId,
      prompt: prompt ?? this.prompt,
      choices: choices ?? this.choices,
      correctIndex: correctIndex ?? this.correctIndex,
    );
  }
}
