/// Represents the enrollment relationship connecting a student to a classroom.
class Enrollment {
  final int? id;
  final int classroomId;
  final int studentId;
  final String enrolledAt;

  const Enrollment({
    this.id,
    required this.classroomId,
    required this.studentId,
    required this.enrolledAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'classroom_id': classroomId,
      'student_id': studentId,
      'enrolled_at': enrolledAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Enrollment.fromMap(Map<String, dynamic> map) {
    return Enrollment(
      id: map['id'] as int?,
      classroomId: map['classroom_id'] as int,
      studentId: map['student_id'] as int,
      enrolledAt: map['enrolled_at'] as String,
    );
  }
}

