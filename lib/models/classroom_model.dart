import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a classroom in Cloud Firestore: classrooms/{classId}
class Classroom {
  final String id;
  final String teacherId;
  final String teacherName;
  final String name;
  final String subject;
  final String code; // 6-character unique join code
  final List<String> studentIds;
  final DateTime? createdAt;

  // Joined presentation fields
  final double? studentOverallPercentage;

  const Classroom({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.name,
    required this.subject,
    required this.code,
    this.studentIds = const [],
    this.createdAt,
    this.studentOverallPercentage,
  });

  int get studentCount => studentIds.length;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'code': code,
      'studentIds': studentIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map, String docId, {double? overallPercentage}) {
    DateTime? parsedCreatedAt;
    final rawCreated = map['createdAt'] ?? map['created_at'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated);
    }

    final rawStudentIds = map['studentIds'] ?? map['student_ids'];
    final List<String> parsedStudentIds = [];
    if (rawStudentIds is List) {
      for (final item in rawStudentIds) {
        parsedStudentIds.add(item.toString());
      }
    }

    return Classroom(
      id: docId,
      teacherId: (map['teacherId'] ?? map['teacher_id'] ?? '').toString(),
      teacherName: (map['teacherName'] ?? map['teacher_name'] ?? 'Instructor') as String,
      name: (map['name'] ?? '') as String,
      subject: (map['subject'] ?? '') as String,
      code: (map['code'] ?? '') as String,
      studentIds: parsedStudentIds,
      createdAt: parsedCreatedAt,
      studentOverallPercentage: overallPercentage ?? (map['overall_percentage'] as num?)?.toDouble(),
    );
  }

  Classroom copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? name,
    String? subject,
    String? code,
    List<String>? studentIds,
    DateTime? createdAt,
    double? studentOverallPercentage,
  }) {
    return Classroom(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      code: code ?? this.code,
      studentIds: studentIds ?? this.studentIds,
      createdAt: createdAt ?? this.createdAt,
      studentOverallPercentage: studentOverallPercentage ?? this.studentOverallPercentage,
    );
  }
}
