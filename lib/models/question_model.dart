/// Represents an academic practice question with a revealable answer.
class Question {
  final int? id;
  final String topic;
  final String question;
  final String answer;
  final int? createdBy; // NULL for seeded system questions, or teacher user_id
  final String createdAt;

  const Question({
    this.id,
    required this.topic,
    required this.question,
    required this.answer,
    this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'topic': topic,
      'question': question,
      'answer': answer,
      'created_by': createdBy,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      topic: map['topic'] as String,
      question: map['question'] as String,
      answer: map['answer'] as String,
      createdBy: map['created_by'] as int?,
      createdAt: map['created_at'] as String,
    );
  }
}

