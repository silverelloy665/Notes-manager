import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic practice question in Cloud Firestore: questions/{questionId}
/// Supports both traditional tap-to-reveal questions, grounded conceptual prompts, and interactive 4-option MCQ flashcards.
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

  // Grounding & Learning-Science Metadata
  final String? documentId; // Source PDF ID or hash
  final int? sourcePage; // Slide or page number from source document
  final String? subtopic; // Subtopic hierarchy
  final String? difficulty; // 'Easy', 'Medium', 'Hard'
  final String? bloomLevel; // 'Remember', 'Understand', 'Apply', 'Analyze', 'Evaluate'
  final String? sourceChunkId; // Linked semantic chunk
  final String? supportingExcerpt; // Direct supporting quote from PDF
  final List<String>? keyPointsRubric; // Rubric items for grading conceptual answers
  final Map<String, String>? distractorReasoning; // Key: option letter, Value: why it is wrong
  final bool isMultiSelect;
  final List<int>? correctOptionIndices;

  // Spaced Repetition (SM-2) & Mastery fields
  final int srsInterval; // In days
  final int srsRepetitions;
  final double srsEaseFactor; // Default 2.5
  final DateTime? nextReviewDate;
  final bool isBookmarked;
  final double? lastScore; // 0.0 to 1.0

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
    this.documentId,
    this.sourcePage,
    this.subtopic,
    this.difficulty = 'Medium',
    this.bloomLevel = 'Understand',
    this.sourceChunkId,
    this.supportingExcerpt,
    this.keyPointsRubric,
    this.distractorReasoning,
    this.isMultiSelect = false,
    this.correctOptionIndices,
    this.srsInterval = 1,
    this.srsRepetitions = 0,
    this.srsEaseFactor = 2.5,
    this.nextReviewDate,
    this.isBookmarked = false,
    this.lastScore,
  });

  bool get isMcq => options != null && options!.length >= 2 && (correctOptionIndex != null || (correctOptionIndices != null && correctOptionIndices!.isNotEmpty));

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
      if (documentId != null) 'documentId': documentId,
      if (sourcePage != null) 'sourcePage': sourcePage,
      if (subtopic != null) 'subtopic': subtopic,
      if (difficulty != null) 'difficulty': difficulty,
      if (bloomLevel != null) 'bloomLevel': bloomLevel,
      if (sourceChunkId != null) 'sourceChunkId': sourceChunkId,
      if (supportingExcerpt != null) 'supportingExcerpt': supportingExcerpt,
      if (keyPointsRubric != null) 'keyPointsRubric': keyPointsRubric,
      if (distractorReasoning != null) 'distractorReasoning': distractorReasoning,
      'isMultiSelect': isMultiSelect,
      if (correctOptionIndices != null) 'correctOptionIndices': correctOptionIndices,
      'srsInterval': srsInterval,
      'srsRepetitions': srsRepetitions,
      'srsEaseFactor': srsEaseFactor,
      if (nextReviewDate != null) 'nextReviewDate': Timestamp.fromDate(nextReviewDate!),
      'isBookmarked': isBookmarked,
      if (lastScore != null) 'lastScore': lastScore,
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

    DateTime? parsedNextReview;
    final rawReview = map['nextReviewDate'];
    if (rawReview is Timestamp) {
      parsedNextReview = rawReview.toDate();
    } else if (rawReview is String) {
      parsedNextReview = DateTime.tryParse(rawReview);
    }

    List<String>? parsedOptions;
    if (map['options'] is List) {
      parsedOptions = (map['options'] as List).map((e) => e.toString()).toList();
    }

    List<String>? parsedRubric;
    if (map['keyPointsRubric'] is List) {
      parsedRubric = (map['keyPointsRubric'] as List).map((e) => e.toString()).toList();
    }

    Map<String, String>? parsedDistractors;
    if (map['distractorReasoning'] is Map) {
      parsedDistractors = Map<String, String>.from(
        (map['distractorReasoning'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    List<int>? parsedMultiIndices;
    if (map['correctOptionIndices'] is List) {
      parsedMultiIndices = (map['correctOptionIndices'] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
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
      documentId: map['documentId']?.toString(),
      sourcePage: map['sourcePage'] != null ? int.tryParse(map['sourcePage'].toString()) : null,
      subtopic: map['subtopic']?.toString(),
      difficulty: map['difficulty']?.toString() ?? 'Medium',
      bloomLevel: map['bloomLevel']?.toString() ?? 'Understand',
      sourceChunkId: map['sourceChunkId']?.toString(),
      supportingExcerpt: map['supportingExcerpt']?.toString(),
      keyPointsRubric: parsedRubric,
      distractorReasoning: parsedDistractors,
      isMultiSelect: map['isMultiSelect'] == true,
      correctOptionIndices: parsedMultiIndices,
      srsInterval: int.tryParse(map['srsInterval']?.toString() ?? '1') ?? 1,
      srsRepetitions: int.tryParse(map['srsRepetitions']?.toString() ?? '0') ?? 0,
      srsEaseFactor: double.tryParse(map['srsEaseFactor']?.toString() ?? '2.5') ?? 2.5,
      nextReviewDate: parsedNextReview,
      isBookmarked: map['isBookmarked'] == true,
      lastScore: map['lastScore'] != null ? double.tryParse(map['lastScore'].toString()) : null,
    );
  }

  Question copyWith({
    String? id,
    String? topic,
    String? question,
    String? answer,
    String? createdBy,
    String? subjectId,
    String? unitId,
    DateTime? createdAt,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    String? documentId,
    int? sourcePage,
    String? subtopic,
    String? difficulty,
    String? bloomLevel,
    String? sourceChunkId,
    String? supportingExcerpt,
    List<String>? keyPointsRubric,
    Map<String, String>? distractorReasoning,
    bool? isMultiSelect,
    List<int>? correctOptionIndices,
    int? srsInterval,
    int? srsRepetitions,
    double? srsEaseFactor,
    DateTime? nextReviewDate,
    bool? isBookmarked,
    double? lastScore,
  }) {
    return Question(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      createdBy: createdBy ?? this.createdBy,
      subjectId: subjectId ?? this.subjectId,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt ?? this.createdAt,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      documentId: documentId ?? this.documentId,
      sourcePage: sourcePage ?? this.sourcePage,
      subtopic: subtopic ?? this.subtopic,
      difficulty: difficulty ?? this.difficulty,
      bloomLevel: bloomLevel ?? this.bloomLevel,
      sourceChunkId: sourceChunkId ?? this.sourceChunkId,
      supportingExcerpt: supportingExcerpt ?? this.supportingExcerpt,
      keyPointsRubric: keyPointsRubric ?? this.keyPointsRubric,
      distractorReasoning: distractorReasoning ?? this.distractorReasoning,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      correctOptionIndices: correctOptionIndices ?? this.correctOptionIndices,
      srsInterval: srsInterval ?? this.srsInterval,
      srsRepetitions: srsRepetitions ?? this.srsRepetitions,
      srsEaseFactor: srsEaseFactor ?? this.srsEaseFactor,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastScore: lastScore ?? this.lastScore,
    );
  }
}
