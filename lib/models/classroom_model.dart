/// Represents a classroom managed by a teacher and joined by students.
class Classroom {
  final int? id;
  final int teacherId;
  final String name;
  final String subject;
  final String code; // 6-character unique code
  final String createdAt;

  // Joined presentation fields
  final String? teacherName;
  final int studentCount;
  final double? studentOverallPercentage;

  const Classroom({
    this.id,
    required this.teacherId,
    required this.name,
    required this.subject,
    required this.code,
    required this.createdAt,
    this.teacherName,
    this.studentCount = 0,
    this.studentOverallPercentage,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'teacher_id': teacherId,
      'name': name,
      'subject': subject,
      'code': code,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      id: map['id'] as int?,
      teacherId: map['teacher_id'] as int,
      name: map['name'] as String,
      subject: map['subject'] as String,
      code: map['code'] as String,
      createdAt: map['created_at'] as String,
      teacherName: map['teacher_name'] as String?,
      studentCount: (map['student_count'] as num?)?.toInt() ?? 0,
      studentOverallPercentage: (map['overall_percentage'] as num?)?.toDouble(),
    );
  }

  Classroom copyWith({
    int? id,
    int? teacherId,
    String? name,
    String? subject,
    String? code,
    String? createdAt,
    String? teacherName,
    int? studentCount,
    double? studentOverallPercentage,
  }) {
    return Classroom(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      teacherName: teacherName ?? this.teacherName,
      studentCount: studentCount ?? this.studentCount,
      studentOverallPercentage:
          studentOverallPercentage ?? this.studentOverallPercentage,
    );
  }
}

