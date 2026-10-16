import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an assessment grade in Cloud Firestore: classrooms/{classId}/grades/{gradeId}
class Grade {
  final String id;
  final String classroomId;
  final String studentId;
  final String studentName;
  final String assessmentTitle;
  final double maxMarks;
  final double marksObtained;
  final String? remarks;
  final DateTime? createdAt;

  const Grade({
    required this.id,
    required this.classroomId,
    required this.studentId,
    this.studentName = '',
    required this.assessmentTitle,
    required this.maxMarks,
    required this.marksObtained,
    this.remarks,
    this.createdAt,
  });

  /// Computed percentage for this assessment.
  double get percentage {
    if (maxMarks <= 0) return 0.0;
    return (marksObtained / maxMarks) * 100.0;
  }

  /// Human-readable percentage string.
  String get percentageString => '${percentage.toStringAsFixed(1)}%';

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'title': assessmentTitle,
      'maxMarks': maxMarks,
      'marksObtained': marksObtained,
      'remarks': remarks,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Grade.fromMap(Map<String, dynamic> map, String docId, {String classroomId = ''}) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'] ?? map['graded_at'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return Grade(
      id: docId,
      classroomId: classroomId.isNotEmpty ? classroomId : (map['classroomId'] ?? map['classroom_id'] ?? '').toString(),
      studentId: (map['studentId'] ?? map['student_id'] ?? '').toString(),
      studentName: (map['studentName'] ?? map['student_name'] ?? '') as String,
      assessmentTitle: (map['title'] ?? map['assessment_title'] ?? '') as String,
      maxMarks: (map['maxMarks'] ?? map['max_marks'] as num? ?? 100.0).toDouble(),
      marksObtained: (map['marksObtained'] ?? map['marks_obtained'] as num? ?? 0.0).toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: parsedCreatedAt,
    );
  }
}

/// Helper model encapsulating aggregate student score within a classroom.
class StudentGradeSummary {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final double totalObtained;
  final double totalMax;
  final int assessmentsCount;

  const StudentGradeSummary({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.totalObtained,
    required this.totalMax,
    required this.assessmentsCount,
  });

  double get overallPercentage {
    if (totalMax <= 0) return 0.0;
    return (totalObtained / totalMax) * 100.0;
  }

  String get overallPercentageString => '${overallPercentage.toStringAsFixed(1)}%';
}
