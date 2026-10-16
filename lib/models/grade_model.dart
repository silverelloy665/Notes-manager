/// Represents an academic assessment evaluation score awarded to an enrolled student.
class Grade {
  final int? id;
  final int classroomId;
  final int studentId;
  final String assessmentTitle;
  final double maxMarks;
  final double marksObtained;
  final String? remarks;
  final String gradedAt;

  const Grade({
    this.id,
    required this.classroomId,
    required this.studentId,
    required this.assessmentTitle,
    required this.maxMarks,
    required this.marksObtained,
    this.remarks,
    required this.gradedAt,
  });

  /// Computed percentage for this assessment.
  double get percentage {
    if (maxMarks <= 0) return 0.0;
    return (marksObtained / maxMarks) * 100.0;
  }

  /// Human-readable percentage string.
  String get percentageString => '${percentage.toStringAsFixed(1)}%';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'classroom_id': classroomId,
      'student_id': studentId,
      'assessment_title': assessmentTitle,
      'max_marks': maxMarks,
      'marks_obtained': marksObtained,
      'remarks': remarks,
      'graded_at': gradedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Grade.fromMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'] as int?,
      classroomId: map['classroom_id'] as int,
      studentId: map['student_id'] as int,
      assessmentTitle: map['assessment_title'] as String,
      maxMarks: (map['max_marks'] as num).toDouble(),
      marksObtained: (map['marks_obtained'] as num).toDouble(),
      remarks: map['remarks'] as String?,
      gradedAt: map['graded_at'] as String,
    );
  }
}

/// Helper model encapsulating a student's profile together with their classroom grade summary.
class StudentGradeSummary {
  final int studentId;
  final String name;
  final String email;
  final String phone;
  final double? overallPercentage;
  final int assessmentsCount;

  const StudentGradeSummary({
    required this.studentId,
    required this.name,
    required this.email,
    required this.phone,
    this.overallPercentage,
    this.assessmentsCount = 0,
  });

  String get percentageDisplay =>
      overallPercentage != null ? '${overallPercentage!.toStringAsFixed(1)}%' : 'Not Graded';
}

