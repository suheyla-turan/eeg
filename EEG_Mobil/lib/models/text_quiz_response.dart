import 'package:cloud_firestore/cloud_firestore.dart';

/// Tek soruya verilen cevap.
class TextQuizAnswer {
  final String questionId;
  final String prompt;
  final int selectedIndex;
  final String selectedLabel;
  final int? correctIndex;
  final bool? isCorrect;

  const TextQuizAnswer({
    required this.questionId,
    required this.prompt,
    required this.selectedIndex,
    required this.selectedLabel,
    this.correctIndex,
    this.isCorrect,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'prompt': prompt,
      'selectedIndex': selectedIndex,
      'selectedLabel': selectedLabel,
      if (correctIndex != null) 'correctIndex': correctIndex,
      if (isCorrect != null) 'isCorrect': isCorrect,
    };
  }

  factory TextQuizAnswer.fromMap(Map<String, dynamic> map) {
    return TextQuizAnswer(
      questionId: map['questionId'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      selectedIndex: (map['selectedIndex'] as num?)?.toInt() ?? -1,
      selectedLabel: map['selectedLabel'] as String? ?? '',
      correctIndex: (map['correctIndex'] as num?)?.toInt(),
      isCorrect: map['isCorrect'] as bool?,
    );
  }
}

/// Metin testi + duygu cevabının tamamı.
class TextQuizResponse {
  final String responseId;
  final String experimentId;
  final String textId;
  final List<TextQuizAnswer> answers;
  final String moodOption;
  final String? moodOtherText;
  final DateTime createdAt;

  const TextQuizResponse({
    required this.responseId,
    required this.experimentId,
    required this.textId,
    required this.answers,
    required this.moodOption,
    this.moodOtherText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'responseId': responseId,
      'experimentId': experimentId,
      'textId': textId,
      'answers': answers.map((a) => a.toMap()).toList(),
      'moodOption': moodOption,
      if (moodOtherText != null && moodOtherText!.isNotEmpty)
        'moodOtherText': moodOtherText,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TextQuizResponse.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawAnswers = map['answers'];
    final answers = rawAnswers is List
        ? rawAnswers
            .whereType<Map>()
            .map((e) => TextQuizAnswer.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <TextQuizAnswer>[];

    return TextQuizResponse(
      responseId: id ?? map['responseId'] as String? ?? '',
      experimentId: map['experimentId'] as String? ?? '',
      textId: map['textId'] as String? ?? '',
      answers: answers,
      moodOption: map['moodOption'] as String? ?? '',
      moodOtherText: map['moodOtherText'] as String?,
      createdAt: _readDate(map['createdAt']),
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
