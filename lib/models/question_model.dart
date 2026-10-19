import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic practice question in Cloud Firestore: questions/{questionId}
/// Supports both traditional tap-to-reveal questions and interactive 4-option MCQ flashcards.
class Question {
  final String id;
  final String topic;
  final String question;
  final String answer;
  final String? createdBy; // NULL for seeded system questions, or student/teacher user_id
  final String? subjectId; // Optional link to imported subject
  final String? unitId; // Optional link to imported unit
  final DateTime? createdAt;
  final List<String>? options; // 4 multiple-choice options for MCQ flashcards
  final int? correctOptionIndex; // 0..3 index of the correct option
  final String? explanation; // Detailed educational explanation for flashcards

  const Question({
    required this.id,
    required this.topic,
    required this.question,
    required this.answer,
    this.createdBy,
    this.subjectId,
    this.unitId,
    this.createdAt,
    this.options,
    this.correctOptionIndex,
    this.explanation,
  });

  bool get isMcq => options != null && options!.length >= 2 && correctOptionIndex != null;

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'question': question,
      'answer': answer,
      'createdBy': createdBy,
      'subjectId': subjectId,
      'unitId': unitId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      if (options != null) 'options': options,
      if (correctOptionIndex != null) 'correctOptionIndex': correctOptionIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'] ?? map['created_at'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    List<String>? parsedOptions;
    if (map['options'] is List) {
      parsedOptions = (map['options'] as List).map((e) => e.toString()).toList();
    }

    int? parsedCorrectIndex;
    if (map['correctOptionIndex'] != null) {
      parsedCorrectIndex = int.tryParse(map['correctOptionIndex'].toString());
    }

    return Question(
      id: docId,
      topic: (map['topic'] ?? 'Other') as String,
      question: (map['question'] ?? '') as String,
      answer: (map['answer'] ?? '') as String,
      createdBy: map['createdBy']?.toString() ?? map['created_by']?.toString(),
      subjectId: map['subjectId']?.toString(),
      unitId: map['unitId']?.toString(),
      createdAt: parsedCreatedAt,
      options: parsedOptions,
      correctOptionIndex: parsedCorrectIndex,
      explanation: map['explanation']?.toString(),
    );
  }
}
