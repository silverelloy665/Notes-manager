import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic subject created or imported by a student:
/// Firestore path: users/{uid}/subjects/{subjectId}
class Subject {
  final String id;
  final String name;
  final DateTime? createdAt;
  final int totalUnits;
  final int completedUnits;

  const Subject({
    required this.id,
    required this.name,
    this.createdAt,
    this.totalUnits = 0,
    this.completedUnits = 0,
  });

  double get progressPercentage {
    if (totalUnits <= 0) return 0.0;
    return (completedUnits / totalUnits) * 100.0;
  }

  String get progressPercentageString => '${progressPercentage.toStringAsFixed(0)}%';

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map, String docId, {int totalUnits = 0, int completedUnits = 0}) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return Subject(
      id: docId,
      name: (map['name'] ?? '') as String,
      createdAt: parsedCreatedAt,
      totalUnits: totalUnits,
      completedUnits: completedUnits,
    );
  }

  Subject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? totalUnits,
    int? completedUnits,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      totalUnits: totalUnits ?? this.totalUnits,
      completedUnits: completedUnits ?? this.completedUnits,
    );
  }
}

/// Represents a curriculum unit within a subject:
/// Firestore path: users/{uid}/subjects/{subjectId}/units/{unitId}
class Unit {
  final String id;
  final String subjectId;
  final int number;
  final String title;
  final bool completed;
  final DateTime? createdAt;
  final int notesCount;
  final int practicalsCount;
  final int questionsCount;

  const Unit({
    required this.id,
    required this.subjectId,
    required this.number,
    required this.title,
    this.completed = false,
    this.createdAt,
    this.notesCount = 0,
    this.practicalsCount = 0,
    this.questionsCount = 0,
  });

  int get totalResources => notesCount + practicalsCount + questionsCount;

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'title': title,
      'completed': completed,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Unit.fromMap(
    Map<String, dynamic> map,
    String docId, {
    String subjectId = '',
    int notesCount = 0,
    int practicalsCount = 0,
    int questionsCount = 0,
  }) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return Unit(
      id: docId,
      subjectId: subjectId,
      number: (map['number'] as num? ?? 1).toInt(),
      title: (map['title'] ?? '') as String,
      completed: map['completed'] == true,
      createdAt: parsedCreatedAt,
      notesCount: notesCount,
      practicalsCount: practicalsCount,
      questionsCount: questionsCount,
    );
  }

  Unit copyWith({
    String? id,
    String? subjectId,
    int? number,
    String? title,
    bool? completed,
    DateTime? createdAt,
    int? notesCount,
    int? practicalsCount,
    int? questionsCount,
  }) {
    return Unit(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      number: number ?? this.number,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      notesCount: notesCount ?? this.notesCount,
      practicalsCount: practicalsCount ?? this.practicalsCount,
      questionsCount: questionsCount ?? this.questionsCount,
    );
  }
}

/// Represents an extracted file resource:
/// Firestore path: users/{uid}/subjects/{subjectId}/units/{unitId}/resources/{resourceId}
class ResourceItem {
  final String id;
  final String subjectId;
  final String unitId;
  final String name;
  final String type; // 'note' or 'practical'
  final String fileType; // extension e.g. 'pdf', 'txt', 'java', 'sql', etc.
  final String relativePath;
  final int sizeBytes;
  final DateTime? createdAt;

  const ResourceItem({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.name,
    required this.type,
    required this.fileType,
    required this.relativePath,
    required this.sizeBytes,
    this.createdAt,
  });

  bool get isPractical => type == 'practical';
  bool get isNote => type == 'note';

  bool get isCodeOrText {
    final ext = fileType.toLowerCase();
    return [
      'txt', 'md', 'java', 'py', 'c', 'cpp', 'dart', 'sql',
      'html', 'css', 'js', 'json', 'xml', 'yaml', 'yml'
    ].contains(ext);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'fileType': fileType,
      'relativePath': relativePath,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ResourceItem.fromMap(Map<String, dynamic> map, String docId, {String subjectId = '', String unitId = ''}) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return ResourceItem(
      id: docId,
      subjectId: subjectId,
      unitId: unitId,
      name: (map['name'] ?? '') as String,
      type: (map['type'] ?? 'note') as String,
      fileType: (map['fileType'] ?? '') as String,
      relativePath: (map['relativePath'] ?? '') as String,
      sizeBytes: (map['sizeBytes'] as num? ?? 0).toInt(),
      createdAt: parsedCreatedAt,
    );
  }
}

/// A parsed file from the ZIP archive before saving.
class ParsedFile {
  final String name;
  final String type; // 'note' or 'practical'
  final String fileType;
  final String relativePath;
  final List<int> bytes;
  final int sizeBytes;

  const ParsedFile({
    required this.name,
    required this.type,
    required this.fileType,
    required this.relativePath,
    required this.bytes,
    required this.sizeBytes,
  });
}

/// A parsed question from optional questions.json.
class ParsedQuestion {
  final String question;
  final String answer;

  const ParsedQuestion({
    required this.question,
    required this.answer,
  });
}

/// A parsed unit containing notes, practicals, and optional questions.
class ParsedUnit {
  final int number;
  final String title;
  final List<ParsedFile> notes;
  final List<ParsedFile> practicals;
  final List<ParsedQuestion> questions;

  const ParsedUnit({
    required this.number,
    required this.title,
    this.notes = const [],
    this.practicals = const [],
    this.questions = const [],
  });

  int get totalFiles => notes.length + practicals.length;

  ParsedUnit copyWith({
    int? number,
    String? title,
    List<ParsedFile>? notes,
    List<ParsedFile>? practicals,
    List<ParsedQuestion>? questions,
  }) {
    return ParsedUnit(
      number: number ?? this.number,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      practicals: practicals ?? this.practicals,
      questions: questions ?? this.questions,
    );
  }
}

/// A parsed subject containing units.
class ParsedSubject {
  final String name;
  final List<ParsedUnit> units;

  const ParsedSubject({
    required this.name,
    this.units = const [],
  });

  int get totalNotes => units.fold(0, (acc, u) => acc + u.notes.length);
  int get totalPracticals => units.fold(0, (acc, u) => acc + u.practicals.length);
  int get totalFiles => totalNotes + totalPracticals;

  ParsedSubject copyWith({
    String? name,
    List<ParsedUnit>? units,
  }) {
    return ParsedSubject(
      name: name ?? this.name,
      units: units ?? this.units,
    );
  }
}

/// Result of ZIP parsing.
class ZipParseResult {
  final List<ParsedSubject> subjects;
  final List<String> skippedFiles;
  final List<String> errors;
  final bool requiresSubjectNamePrompt;

  const ZipParseResult({
    this.subjects = const [],
    this.skippedFiles = const [],
    this.errors = const [],
    this.requiresSubjectNamePrompt = false,
  });

  int get totalNotes => subjects.fold(0, (acc, s) => acc + s.totalNotes);
  int get totalPracticals => subjects.fold(0, (acc, s) => acc + s.totalPracticals);
  int get totalFiles => totalNotes + totalPracticals;
  int get totalUnits => subjects.fold(0, (acc, s) => acc + s.units.length);
  int get totalSubjects => subjects.length;

  ZipParseResult copyWith({
    List<ParsedSubject>? subjects,
    List<String>? skippedFiles,
    List<String>? errors,
    bool? requiresSubjectNamePrompt,
  }) {
    return ZipParseResult(
      subjects: subjects ?? this.subjects,
      skippedFiles: skippedFiles ?? this.skippedFiles,
      errors: errors ?? this.errors,
      requiresSubjectNamePrompt: requiresSubjectNamePrompt ?? this.requiresSubjectNamePrompt,
    );
  }
}
