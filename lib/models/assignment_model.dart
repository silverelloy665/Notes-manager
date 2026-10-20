import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a level within a grading rubric criterion (e.g. Excellent, Good, Fair, Needs Work).
class RubricLevel {
  final String title;
  final String description;
  final double points;

  const RubricLevel({
    required this.title,
    required this.description,
    required this.points,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'points': points,
  };

  factory RubricLevel.fromMap(Map<String, dynamic> map) {
    return RubricLevel(
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      points: double.tryParse(map['points']?.toString() ?? '0') ?? 0.0,
    );
  }
}

/// Represents a single grading criterion in an assignment rubric.
class AssignmentRubricCriterion {
  final String title;
  final String description;
  final double maxPoints;
  final List<RubricLevel> levels;

  const AssignmentRubricCriterion({
    required this.title,
    this.description = '',
    required this.maxPoints,
    this.levels = const [],
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'maxPoints': maxPoints,
    'levels': levels.map((l) => l.toMap()).toList(),
  };

  factory AssignmentRubricCriterion.fromMap(Map<String, dynamic> map) {
    List<RubricLevel> parsedLevels = [];
    if (map['levels'] is List) {
      parsedLevels = (map['levels'] as List)
          .map((l) => RubricLevel.fromMap(l as Map<String, dynamic>))
          .toList();
    }
    return AssignmentRubricCriterion(
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      maxPoints: double.tryParse(map['maxPoints']?.toString() ?? '10.0') ?? 10.0,
      levels: parsedLevels,
    );
  }
}

/// Represents an attached file or link in an assignment or student submission.
class AssignmentAttachment {
  final String fileName;
  final String fileUrl;
  final String fileType; // 'pdf', 'zip', 'image', 'link', 'code'
  final int? fileSizeBytes;

  const AssignmentAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    this.fileSizeBytes,
  });

  Map<String, dynamic> toMap() => {
    'fileName': fileName,
    'fileUrl': fileUrl,
    'fileType': fileType,
    if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
  };

  factory AssignmentAttachment.fromMap(Map<String, dynamic> map) {
    return AssignmentAttachment(
      fileName: (map['fileName'] ?? '') as String,
      fileUrl: (map['fileUrl'] ?? '') as String,
      fileType: (map['fileType'] ?? 'pdf') as String,
      fileSizeBytes: map['fileSizeBytes'] != null ? int.tryParse(map['fileSizeBytes'].toString()) : null,
    );
  }
}

/// Represents a classroom assignment in Cloud Firestore:
/// classrooms/{classId}/assignments/{assignmentId}
class Assignment {
  final String id;
  final String classroomId;
  final String title;
  final int? unitNumber;
  final String instructions;
  final List<AssignmentAttachment> referenceAttachments;
  final double totalPoints;
  final DateTime dueDate;
  final bool allowLateSubmissions;
  final double latePenaltyPercentPerDay; // e.g. 5.0 for 5%/day
  final List<AssignmentRubricCriterion> rubricCriteria;
  final String status; // 'draft', 'published', 'scheduled'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Assignment({
    required this.id,
    required this.classroomId,
    required this.title,
    this.unitNumber,
    required this.instructions,
    this.referenceAttachments = const [],
    this.totalPoints = 100.0,
    required this.dueDate,
    this.allowLateSubmissions = true,
    this.latePenaltyPercentPerDay = 5.0,
    this.rubricCriteria = const [],
    this.status = 'published',
    this.createdAt,
    this.updatedAt,
  });

  bool get isPastDue => DateTime.now().isAfter(dueDate);

  String get dueRelativeText {
    final diff = dueDate.difference(DateTime.now());
    if (diff.isNegative) {
      final past = -diff.inHours;
      if (past < 24) return 'Past due by $past hours';
      return 'Past due by ${(past / 24).round()} days';
    }
    if (diff.inDays > 1) return 'Due in ${diff.inDays} days';
    if (diff.inHours > 1) return 'Due in ${diff.inHours} hours';
    return 'Due in ${diff.inMinutes} minutes';
  }

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'title': title,
      if (unitNumber != null) 'unitNumber': unitNumber,
      'instructions': instructions,
      'referenceAttachments': referenceAttachments.map((a) => a.toMap()).toList(),
      'totalPoints': totalPoints,
      'dueDate': Timestamp.fromDate(dueDate),
      'allowLateSubmissions': allowLateSubmissions,
      'latePenaltyPercentPerDay': latePenaltyPercentPerDay,
      'rubricCriteria': rubricCriteria.map((r) => r.toMap()).toList(),
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map, String docId, {required String classroomId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<AssignmentAttachment> parsedAttachments = [];
    if (map['referenceAttachments'] is List) {
      parsedAttachments = (map['referenceAttachments'] as List)
          .map((a) => AssignmentAttachment.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    List<AssignmentRubricCriterion> parsedRubrics = [];
    if (map['rubricCriteria'] is List) {
      parsedRubrics = (map['rubricCriteria'] as List)
          .map((r) => AssignmentRubricCriterion.fromMap(r as Map<String, dynamic>))
          .toList();
    }

    return Assignment(
      id: docId,
      classroomId: classroomId,
      title: (map['title'] ?? 'Untitled Assignment') as String,
      unitNumber: map['unitNumber'] != null ? int.tryParse(map['unitNumber'].toString()) : null,
      instructions: (map['instructions'] ?? '') as String,
      referenceAttachments: parsedAttachments,
      totalPoints: double.tryParse(map['totalPoints']?.toString() ?? '100.0') ?? 100.0,
      dueDate: parseDate(map['dueDate']) ?? DateTime.now().add(const Duration(days: 7)),
      allowLateSubmissions: map['allowLateSubmissions'] ?? true,
      latePenaltyPercentPerDay: double.tryParse(map['latePenaltyPercentPerDay']?.toString() ?? '5.0') ?? 5.0,
      rubricCriteria: parsedRubrics,
      status: (map['status'] ?? 'published') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Assignment copyWith({
    String? id,
    String? classroomId,
    String? title,
    int? unitNumber,
    String? instructions,
    List<AssignmentAttachment>? referenceAttachments,
    double? totalPoints,
    DateTime? dueDate,
    bool? allowLateSubmissions,
    double? latePenaltyPercentPerDay,
    List<AssignmentRubricCriterion>? rubricCriteria,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      title: title ?? this.title,
      unitNumber: unitNumber ?? this.unitNumber,
      instructions: instructions ?? this.instructions,
      referenceAttachments: referenceAttachments ?? this.referenceAttachments,
      totalPoints: totalPoints ?? this.totalPoints,
      dueDate: dueDate ?? this.dueDate,
      allowLateSubmissions: allowLateSubmissions ?? this.allowLateSubmissions,
      latePenaltyPercentPerDay: latePenaltyPercentPerDay ?? this.latePenaltyPercentPerDay,
      rubricCriteria: rubricCriteria ?? this.rubricCriteria,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents a student's submission to an assignment:
/// classrooms/{classId}/assignments/{assignmentId}/submissions/{studentId}
class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String classroomId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final List<AssignmentAttachment> submittedFiles;
  final String? textResponse;
  final DateTime? submittedAt;
  final bool isLate;
  final double? pointsAwarded;
  final double maxPoints;
  final Map<String, double> rubricScores; // criterionTitle -> points
  final String? feedback;
  final String status; // 'assigned', 'turned_in', 'turned_in_late', 'graded', 'returned'
  final DateTime? gradedAt;
  final String? gradedBy;

  const AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.classroomId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.submittedFiles = const [],
    this.textResponse,
    this.submittedAt,
    this.isLate = false,
    this.pointsAwarded,
    this.maxPoints = 100.0,
    this.rubricScores = const {},
    this.feedback,
    this.status = 'turned_in',
    this.gradedAt,
    this.gradedBy,
  });

  bool get isGraded => status == 'graded' || status == 'returned';

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'classroomId': classroomId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'submittedFiles': submittedFiles.map((f) => f.toMap()).toList(),
      if (textResponse != null) 'textResponse': textResponse,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      'isLate': isLate,
      if (pointsAwarded != null) 'pointsAwarded': pointsAwarded,
      'maxPoints': maxPoints,
      'rubricScores': rubricScores,
      if (feedback != null) 'feedback': feedback,
      'status': status,
      if (gradedAt != null) 'gradedAt': Timestamp.fromDate(gradedAt!),
      if (gradedBy != null) 'gradedBy': gradedBy,
    };
  }

  factory AssignmentSubmission.fromMap(Map<String, dynamic> map, String docId, {required String classroomId, required String assignmentId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<AssignmentAttachment> parsedFiles = [];
    if (map['submittedFiles'] is List) {
      parsedFiles = (map['submittedFiles'] as List)
          .map((f) => AssignmentAttachment.fromMap(f as Map<String, dynamic>))
          .toList();
    }

    Map<String, double> parsedRubric = {};
    if (map['rubricScores'] is Map) {
      (map['rubricScores'] as Map).forEach((k, v) {
        parsedRubric[k.toString()] = double.tryParse(v.toString()) ?? 0.0;
      });
    }

    return AssignmentSubmission(
      id: docId,
      assignmentId: assignmentId,
      classroomId: classroomId,
      studentId: (map['studentId'] ?? '') as String,
      studentName: (map['studentName'] ?? 'Student') as String,
      studentEmail: (map['studentEmail'] ?? '') as String,
      submittedFiles: parsedFiles,
      textResponse: map['textResponse']?.toString(),
      submittedAt: parseDate(map['submittedAt']),
      isLate: map['isLate'] == true,
      pointsAwarded: map['pointsAwarded'] != null ? double.tryParse(map['pointsAwarded'].toString()) : null,
      maxPoints: double.tryParse(map['maxPoints']?.toString() ?? '100.0') ?? 100.0,
      rubricScores: parsedRubric,
      feedback: map['feedback']?.toString(),
      status: (map['status'] ?? 'turned_in') as String,
      gradedAt: parseDate(map['gradedAt']),
      gradedBy: map['gradedBy']?.toString(),
    );
  }

  AssignmentSubmission copyWith({
    String? id,
    String? assignmentId,
    String? classroomId,
    String? studentId,
    String? studentName,
    String? studentEmail,
    List<AssignmentAttachment>? submittedFiles,
    String? textResponse,
    DateTime? submittedAt,
    bool? isLate,
    double? pointsAwarded,
    double? maxPoints,
    Map<String, double>? rubricScores,
    String? feedback,
    String? status,
    DateTime? gradedAt,
    String? gradedBy,
  }) {
    return AssignmentSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      classroomId: classroomId ?? this.classroomId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      submittedFiles: submittedFiles ?? this.submittedFiles,
      textResponse: textResponse ?? this.textResponse,
      submittedAt: submittedAt ?? this.submittedAt,
      isLate: isLate ?? this.isLate,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      maxPoints: maxPoints ?? this.maxPoints,
      rubricScores: rubricScores ?? this.rubricScores,
      feedback: feedback ?? this.feedback,
      status: status ?? this.status,
      gradedAt: gradedAt ?? this.gradedAt,
      gradedBy: gradedBy ?? this.gradedBy,
    );
  }
}
