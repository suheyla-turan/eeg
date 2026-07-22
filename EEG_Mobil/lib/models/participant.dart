import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String participantId;
  final String participantCode;
  final String firstName;
  final String lastName;
  final String gender;
  final int age;
  final DateTime? birthDate;
  final String education;
  final String occupation;
  final String dailySocialMediaUsage;
  final String dominantHand;
  final bool visionProblem;
  final String sleepDuration;
  final String notes;
  final DateTime createdAt;

  const Participant({
    required this.participantId,
    required this.participantCode,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.age,
    this.birthDate,
    required this.education,
    required this.occupation,
    required this.dailySocialMediaUsage,
    required this.dominantHand,
    required this.visionProblem,
    required this.sleepDuration,
    required this.notes,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'participantId': participantId,
      'participantCode': participantCode,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'age': age,
      'birthDate':
          birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'education': education,
      'occupation': occupation,
      'dailySocialMediaUsage': dailySocialMediaUsage,
      'dominantHand': dominantHand,
      'visionProblem': visionProblem,
      'sleepDuration': sleepDuration,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map, {String? id}) {
    return Participant(
      participantId: id ?? map['participantId'] as String? ?? '',
      participantCode: map['participantCode'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      birthDate: _readDateOrNull(map['birthDate']),
      education: map['education'] as String? ?? '',
      occupation: map['occupation'] as String? ?? '',
      dailySocialMediaUsage: map['dailySocialMediaUsage'] as String? ?? '',
      dominantHand: map['dominantHand'] as String? ?? '',
      visionProblem: map['visionProblem'] as bool? ?? false,
      sleepDuration: map['sleepDuration'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: _readDate(map['createdAt']),
    );
  }

  Participant copyWith({
    String? participantId,
    String? participantCode,
    String? firstName,
    String? lastName,
    String? gender,
    int? age,
    DateTime? birthDate,
    String? education,
    String? occupation,
    String? dailySocialMediaUsage,
    String? dominantHand,
    bool? visionProblem,
    String? sleepDuration,
    String? notes,
    DateTime? createdAt,
  }) {
    return Participant(
      participantId: participantId ?? this.participantId,
      participantCode: participantCode ?? this.participantCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      education: education ?? this.education,
      occupation: occupation ?? this.occupation,
      dailySocialMediaUsage:
          dailySocialMediaUsage ?? this.dailySocialMediaUsage,
      dominantHand: dominantHand ?? this.dominantHand,
      visionProblem: visionProblem ?? this.visionProblem,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

DateTime? _readDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
