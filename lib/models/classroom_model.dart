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

  // Additional settings and permissions
  final String? description;
  final bool isJoiningEnabled;
  final bool requireApproval;
  final List<String> pendingStudentIds;
  final List<String> coTeacherIds;
  final bool isArchived;

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
    this.description,
    this.isJoiningEnabled = true,
    this.requireApproval = false,
    this.pendingStudentIds = const [],
    this.coTeacherIds = const [],
    this.isArchived = false,
    this.studentOverallPercentage,
  });

  int get studentCount => studentIds.length;
  int get pendingCount => pendingStudentIds.length;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'code': code,
      'studentIds': studentIds,
      'description': description ?? '',
      'isJoiningEnabled': isJoiningEnabled,
      'requireApproval': requireApproval,
      'pendingStudentIds': pendingStudentIds,
      'coTeacherIds': coTeacherIds,
      'isArchived': isArchived,
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

    final rawPendingIds = map['pendingStudentIds'] ?? map['pending_student_ids'];
    final List<String> parsedPendingIds = [];
    if (rawPendingIds is List) {
      for (final item in rawPendingIds) {
        parsedPendingIds.add(item.toString());
      }
    }

    final rawCoTeacherIds = map['coTeacherIds'] ?? map['co_teacher_ids'];
    final List<String> parsedCoTeacherIds = [];
    if (rawCoTeacherIds is List) {
      for (final item in rawCoTeacherIds) {
        parsedCoTeacherIds.add(item.toString());
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
      description: map['description'] as String?,
      isJoiningEnabled: (map['isJoiningEnabled'] ?? true) as bool,
      requireApproval: (map['requireApproval'] ?? false) as bool,
      pendingStudentIds: parsedPendingIds,
      coTeacherIds: parsedCoTeacherIds,
      isArchived: (map['isArchived'] ?? false) as bool,
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
    String? description,
    bool? isJoiningEnabled,
    bool? requireApproval,
    List<String>? pendingStudentIds,
    List<String>? coTeacherIds,
    bool? isArchived,
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
      description: description ?? this.description,
      isJoiningEnabled: isJoiningEnabled ?? this.isJoiningEnabled,
      requireApproval: requireApproval ?? this.requireApproval,
      pendingStudentIds: pendingStudentIds ?? this.pendingStudentIds,
      coTeacherIds: coTeacherIds ?? this.coTeacherIds,
      isArchived: isArchived ?? this.isArchived,
      studentOverallPercentage: studentOverallPercentage ?? this.studentOverallPercentage,
    );
  }
}
