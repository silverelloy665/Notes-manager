import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studymate_classroom/models/question_model.dart';

/// Represents a formal timed classroom exam or assessment in Cloud Firestore:
/// classrooms/{classId}/exams/{examId}
class Exam {
  final String id;
  final String classroomId;
  final String title;
  final String subject;
  final int? unitNumber;
  final String? unitTitle;
  final String instructions;
  final int durationMinutes;
  final DateTime? startWindow;
  final DateTime? endWindow;
  final double passingMarks;
  final double totalMarks;
  final int attemptsAllowed; // 1 = single attempt, >1 = retries allowed
  final List<Question> questions;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool fullScreenEnforced;
  final int tabSwitchLimit; // e.g. 3 (0 = disabled)
  final bool disableCopyPaste;
  final bool allowCalculator;
  final bool watermarkStudentId;
  final bool releaseScoresImmediately;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Exam({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.subject,
    this.unitNumber,
    this.unitTitle,
    this.instructions = 'Answer all questions carefully. Maintain focus in this window until submission.',
    this.durationMinutes = 60,
    this.startWindow,
    this.endWindow,
    this.passingMarks = 40.0,
    this.totalMarks = 100.0,
    this.attemptsAllowed = 1,
    this.questions = const [],
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.fullScreenEnforced = true,
    this.tabSwitchLimit = 3,
    this.disableCopyPaste = true,
    this.allowCalculator = true,
    this.watermarkStudentId = true,
    this.releaseScoresImmediately = false,
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOngoing {
    final now = DateTime.now();
    if (startWindow != null && now.isBefore(startWindow!)) return false;
    if (endWindow != null && now.isAfter(endWindow!)) return false;
    return isPublished;
  }

  bool get isExpired {
    if (endWindow == null) return false;
    return DateTime.now().isAfter(endWindow!);
  }

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'title': title,
      'subject': subject,
      if (unitNumber != null) 'unitNumber': unitNumber,
      if (unitTitle != null) 'unitTitle': unitTitle,
      'instructions': instructions,
      'durationMinutes': durationMinutes,
      if (startWindow != null) 'startWindow': Timestamp.fromDate(startWindow!),
      if (endWindow != null) 'endWindow': Timestamp.fromDate(endWindow!),
      'passingMarks': passingMarks,
      'totalMarks': totalMarks,
      'attemptsAllowed': attemptsAllowed,
      'questions': questions.map((q) => q.toMap()).toList(),
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'fullScreenEnforced': fullScreenEnforced,
      'tabSwitchLimit': tabSwitchLimit,
      'disableCopyPaste': disableCopyPaste,
      'allowCalculator': allowCalculator,
      'watermarkStudentId': watermarkStudentId,
      'releaseScoresImmediately': releaseScoresImmediately,
      'isPublished': isPublished,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map, String docId, {required String classroomId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<Question> parsedQuestions = [];
    if (map['questions'] is List) {
      parsedQuestions = (map['questions'] as List).asMap().entries.map((entry) {
        final qMap = entry.value as Map<String, dynamic>;
        final qId = qMap['id']?.toString() ?? 'q_${entry.key}';
        return Question.fromMap(qMap, qId);
      }).toList();
    }

    return Exam(
      id: docId,
      classroomId: classroomId,
      title: (map['title'] ?? 'Untitled Exam') as String,
      subject: (map['subject'] ?? '') as String,
      unitNumber: map['unitNumber'] != null ? int.tryParse(map['unitNumber'].toString()) : null,
      unitTitle: map['unitTitle']?.toString(),
      instructions: map['instructions']?.toString() ?? 'Answer all questions carefully.',
      durationMinutes: int.tryParse(map['durationMinutes']?.toString() ?? '60') ?? 60,
      startWindow: parseDate(map['startWindow']),
      endWindow: parseDate(map['endWindow']),
      passingMarks: double.tryParse(map['passingMarks']?.toString() ?? '40.0') ?? 40.0,
      totalMarks: double.tryParse(map['totalMarks']?.toString() ?? '100.0') ?? 100.0,
      attemptsAllowed: int.tryParse(map['attemptsAllowed']?.toString() ?? '1') ?? 1,
      questions: parsedQuestions,
      shuffleQuestions: map['shuffleQuestions'] ?? true,
      shuffleOptions: map['shuffleOptions'] ?? true,
      fullScreenEnforced: map['fullScreenEnforced'] ?? true,
      tabSwitchLimit: int.tryParse(map['tabSwitchLimit']?.toString() ?? '3') ?? 3,
      disableCopyPaste: map['disableCopyPaste'] ?? true,
      allowCalculator: map['allowCalculator'] ?? true,
      watermarkStudentId: map['watermarkStudentId'] ?? true,
      releaseScoresImmediately: map['releaseScoresImmediately'] ?? false,
      isPublished: map['isPublished'] ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Exam copyWith({
    String? id,
    String? classroomId,
    String? title,
    String? subject,
    int? unitNumber,
    String? unitTitle,
    String? instructions,
    int? durationMinutes,
    DateTime? startWindow,
    DateTime? endWindow,
    double? passingMarks,
    double? totalMarks,
    int? attemptsAllowed,
    List<Question>? questions,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? fullScreenEnforced,
    int? tabSwitchLimit,
    bool? disableCopyPaste,
    bool? allowCalculator,
    bool? watermarkStudentId,
    bool? releaseScoresImmediately,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exam(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      unitNumber: unitNumber ?? this.unitNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      instructions: instructions ?? this.instructions,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startWindow: startWindow ?? this.startWindow,
      endWindow: endWindow ?? this.endWindow,
      passingMarks: passingMarks ?? this.passingMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      attemptsAllowed: attemptsAllowed ?? this.attemptsAllowed,
      questions: questions ?? this.questions,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      fullScreenEnforced: fullScreenEnforced ?? this.fullScreenEnforced,
      tabSwitchLimit: tabSwitchLimit ?? this.tabSwitchLimit,
      disableCopyPaste: disableCopyPaste ?? this.disableCopyPaste,
      allowCalculator: allowCalculator ?? this.allowCalculator,
      watermarkStudentId: watermarkStudentId ?? this.watermarkStudentId,
      releaseScoresImmediately: releaseScoresImmediately ?? this.releaseScoresImmediately,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents a student's submission / test-taking session for an exam in Cloud Firestore:
/// classrooms/{classId}/exams/{examId}/submissions/{studentId}
class ExamSubmission {
  final String id;
  final String examId;
  final String classroomId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final Map<String, dynamic> answers; // questionId -> chosenOptionIndex or text
  final Map<String, double> questionScores; // questionId -> marks
  final Map<String, String> questionFeedback; // questionId -> AI/Teacher feedback
  final List<String> flaggedQuestionIds;
  final int tabSwitchCount;
  final List<DateTime> tabSwitchLogs;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final double totalMarksObtained;
  final double maxMarks;
  final double percentage;
  final bool isPassed;
  final String status; // 'in_progress', 'submitted', 'graded', 'released'

  const ExamSubmission({
    required this.id,
    required this.examId,
    required this.classroomId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.answers = const {},
    this.questionScores = const {},
    this.questionFeedback = const {},
    this.flaggedQuestionIds = const [],
    this.tabSwitchCount = 0,
    this.tabSwitchLogs = const [],
    this.startedAt,
    this.submittedAt,
    this.totalMarksObtained = 0.0,
    this.maxMarks = 100.0,
    this.percentage = 0.0,
    this.isPassed = false,
    this.status = 'submitted',
  });

  bool get isGraded => status == 'graded' || status == 'released';
  bool get isReleased => status == 'released';

  Map<String, dynamic> toMap() {
    return {
      'examId': examId,
      'classroomId': classroomId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'answers': answers,
      'questionScores': questionScores,
      'questionFeedback': questionFeedback,
      'flaggedQuestionIds': flaggedQuestionIds,
      'tabSwitchCount': tabSwitchCount,
      'tabSwitchLogs': tabSwitchLogs.map((d) => Timestamp.fromDate(d)).toList(),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      'totalMarksObtained': totalMarksObtained,
      'maxMarks': maxMarks,
      'percentage': percentage,
      'isPassed': isPassed,
      'status': status,
    };
  }

  factory ExamSubmission.fromMap(Map<String, dynamic> map, String docId, {required String classroomId, required String examId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<String, dynamic> parsedAnswers = {};
    if (map['answers'] is Map) {
      parsedAnswers = Map<String, dynamic>.from(map['answers'] as Map);
    }

    Map<String, double> parsedScores = {};
    if (map['questionScores'] is Map) {
      (map['questionScores'] as Map).forEach((k, v) {
        parsedScores[k.toString()] = double.tryParse(v.toString()) ?? 0.0;
      });
    }

    Map<String, String> parsedFeedback = {};
    if (map['questionFeedback'] is Map) {
      (map['questionFeedback'] as Map).forEach((k, v) {
        parsedFeedback[k.toString()] = v.toString();
      });
    }

    List<String> parsedFlags = [];
    if (map['flaggedQuestionIds'] is List) {
      parsedFlags = (map['flaggedQuestionIds'] as List).map((e) => e.toString()).toList();
    }

    List<DateTime> parsedLogs = [];
    if (map['tabSwitchLogs'] is List) {
      for (final item in map['tabSwitchLogs'] as List) {
        final d = parseDate(item);
        if (d != null) parsedLogs.add(d);
      }
    }

    return ExamSubmission(
      id: docId,
      examId: examId,
      classroomId: classroomId,
      studentId: (map['studentId'] ?? '') as String,
      studentName: (map['studentName'] ?? 'Student') as String,
      studentEmail: (map['studentEmail'] ?? '') as String,
      answers: parsedAnswers,
      questionScores: parsedScores,
      questionFeedback: parsedFeedback,
      flaggedQuestionIds: parsedFlags,
      tabSwitchCount: int.tryParse(map['tabSwitchCount']?.toString() ?? '0') ?? 0,
      tabSwitchLogs: parsedLogs,
      startedAt: parseDate(map['startedAt']),
      submittedAt: parseDate(map['submittedAt']),
      totalMarksObtained: double.tryParse(map['totalMarksObtained']?.toString() ?? '0.0') ?? 0.0,
      maxMarks: double.tryParse(map['maxMarks']?.toString() ?? '100.0') ?? 100.0,
      percentage: double.tryParse(map['percentage']?.toString() ?? '0.0') ?? 0.0,
      isPassed: map['isPassed'] == true,
      status: (map['status'] ?? 'submitted') as String,
    );
  }

  ExamSubmission copyWith({
    String? id,
    String? examId,
    String? classroomId,
    String? studentId,
    String? studentName,
    String? studentEmail,
    Map<String, dynamic>? answers,
    Map<String, double>? questionScores,
    Map<String, String>? questionFeedback,
    List<String>? flaggedQuestionIds,
    int? tabSwitchCount,
    List<DateTime>? tabSwitchLogs,
    DateTime? startedAt,
    DateTime? submittedAt,
    double? totalMarksObtained,
    double? maxMarks,
    double? percentage,
    bool? isPassed,
    String? status,
  }) {
    return ExamSubmission(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      classroomId: classroomId ?? this.classroomId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      answers: answers ?? this.answers,
      questionScores: questionScores ?? this.questionScores,
      questionFeedback: questionFeedback ?? this.questionFeedback,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      tabSwitchCount: tabSwitchCount ?? this.tabSwitchCount,
      tabSwitchLogs: tabSwitchLogs ?? this.tabSwitchLogs,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      totalMarksObtained: totalMarksObtained ?? this.totalMarksObtained,
      maxMarks: maxMarks ?? this.maxMarks,
      percentage: percentage ?? this.percentage,
      isPassed: isPassed ?? this.isPassed,
      status: status ?? this.status,
    );
  }
}
