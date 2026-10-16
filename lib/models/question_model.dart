import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic practice question in Cloud Firestore: questions/{questionId}
class Question {
  final String id;
  final String topic;
  final String question;
  final String answer;
  final String? createdBy; // NULL for seeded system questions, or teacher user_id
  final String? subjectId; // Optional link to imported subject
  final String? unitId; // Optional link to imported unit
  final DateTime? createdAt;

  const Question({
    required this.id,
    required this.topic,
    required this.question,
    required this.answer,
    this.createdBy,
    this.subjectId,
    this.unitId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'question': question,
      'answer': answer,
      'createdBy': createdBy,
      'subjectId': subjectId,
      'unitId': unitId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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

    return Question(
      id: docId,
      topic: (map['topic'] ?? 'Other') as String,
      question: (map['question'] ?? '') as String,
      answer: (map['answer'] ?? '') as String,
      createdBy: map['createdBy']?.toString() ?? map['created_by']?.toString(),
      subjectId: map['subjectId']?.toString(),
      unitId: map['unitId']?.toString(),
      createdAt: parsedCreatedAt,
    );
  }
}
