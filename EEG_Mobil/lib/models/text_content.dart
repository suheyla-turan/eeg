import 'package:cloud_firestore/cloud_firestore.dart';

import 'text_quiz_question.dart';

class TextContent {
  final String textId;
  final String title;
  final String content;
  final int estimatedDuration;
  final String difficulty;
  final bool active;
  final DateTime createdAt;
  final List<TextQuizQuestion> questions;

  const TextContent({
    required this.textId,
    required this.title,
    required this.content,
    required this.estimatedDuration,
    required this.difficulty,
    this.active = true,
    required this.createdAt,
    this.questions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'textId': textId,
      'title': title,
      'content': content,
      'estimatedDuration': estimatedDuration,
      'difficulty': difficulty,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory TextContent.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawQuestions = map['questions'];
    final questions = rawQuestions is List
        ? rawQuestions
            .whereType<Map>()
            .map((e) => TextQuizQuestion.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <TextQuizQuestion>[];

    return TextContent(
      textId: id ?? map['textId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      estimatedDuration: (map['estimatedDuration'] as num?)?.toInt() ?? 0,
      difficulty: map['difficulty'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      createdAt: _readDate(map['createdAt']),
      questions: questions,
    );
  }

  TextContent copyWith({
    String? textId,
    String? title,
    String? content,
    int? estimatedDuration,
    String? difficulty,
    bool? active,
    DateTime? createdAt,
    List<TextQuizQuestion>? questions,
  }) {
    return TextContent(
      textId: textId ?? this.textId,
      title: title ?? this.title,
      content: content ?? this.content,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      difficulty: difficulty ?? this.difficulty,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
