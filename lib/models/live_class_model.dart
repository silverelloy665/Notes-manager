import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a student's attendance log in a live class session.
class StudentAttendanceRecord {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final int durationSeconds;

  const StudentAttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.joinedAt,
    this.leftAt,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'joinedAt': Timestamp.fromDate(joinedAt),
    if (leftAt != null) 'leftAt': Timestamp.fromDate(leftAt!),
    'durationSeconds': durationSeconds,
  };

  factory StudentAttendanceRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return StudentAttendanceRecord(
      studentId: (map['studentId'] ?? '') as String,
      studentName: (map['studentName'] ?? 'Student') as String,
      studentEmail: (map['studentEmail'] ?? '') as String,
      joinedAt: parseDate(map['joinedAt']) ?? DateTime.now(),
      leftAt: parseDate(map['leftAt']),
      durationSeconds: int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Represents a live lecture / video meeting session in Cloud Firestore:
/// classrooms/{classId}/live_classes/{sessionId}
class LiveClassSession {
  final String id;
  final String classroomId;
  final String title;
  final int? unitNumber;
  final String? unitTitle;
  final String roomName;
  final String hostTeacherId;
  final String hostTeacherName;
  final bool isOngoing;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final Map<String, StudentAttendanceRecord> attendanceRecords; // studentId -> record

  const LiveClassSession({
    required this.id,
    required this.classroomId,
    required this.title,
    this.unitNumber,
    this.unitTitle,
    required this.roomName,
    required this.hostTeacherId,
    required this.hostTeacherName,
    this.isOngoing = true,
    required this.startedAt,
    this.endedAt,
    this.notes,
    this.attendanceRecords = const {},
  });

  String get meetUrl => 'https://meet.jit.si/$roomName';

  int get durationMinutes {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt).inMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'title': title,
      if (unitNumber != null) 'unitNumber': unitNumber,
      if (unitTitle != null) 'unitTitle': unitTitle,
      'roomName': roomName,
      'hostTeacherId': hostTeacherId,
      'hostTeacherName': hostTeacherName,
      'isOngoing': isOngoing,
      'startedAt': Timestamp.fromDate(startedAt),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      if (notes != null) 'notes': notes,
      'attendanceRecords': attendanceRecords.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory LiveClassSession.fromMap(Map<String, dynamic> map, String docId, {required String classroomId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<String, StudentAttendanceRecord> parsedAttendance = {};
    if (map['attendanceRecords'] is Map) {
      (map['attendanceRecords'] as Map).forEach((k, v) {
        if (v is Map) {
          parsedAttendance[k.toString()] = StudentAttendanceRecord.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    return LiveClassSession(
      id: docId,
      classroomId: classroomId,
      title: (map['title'] ?? 'Live Class') as String,
      unitNumber: map['unitNumber'] != null ? int.tryParse(map['unitNumber'].toString()) : null,
      unitTitle: map['unitTitle']?.toString(),
      roomName: (map['roomName'] ?? '') as String,
      hostTeacherId: (map['hostTeacherId'] ?? '') as String,
      hostTeacherName: (map['hostTeacherName'] ?? 'Faculty') as String,
      isOngoing: map['isOngoing'] == true,
      startedAt: parseDate(map['startedAt']) ?? DateTime.now(),
      endedAt: parseDate(map['endedAt']),
      notes: map['notes']?.toString(),
      attendanceRecords: parsedAttendance,
    );
  }

  LiveClassSession copyWith({
    String? id,
    String? classroomId,
    String? title,
    int? unitNumber,
    String? unitTitle,
    String? roomName,
    String? hostTeacherId,
    String? hostTeacherName,
    bool? isOngoing,
    DateTime? startedAt,
    DateTime? endedAt,
    String? notes,
    Map<String, StudentAttendanceRecord>? attendanceRecords,
  }) {
    return LiveClassSession(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      title: title ?? this.title,
      unitNumber: unitNumber ?? this.unitNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      roomName: roomName ?? this.roomName,
      hostTeacherId: hostTeacherId ?? this.hostTeacherId,
      hostTeacherName: hostTeacherName ?? this.hostTeacherName,
      isOngoing: isOngoing ?? this.isOngoing,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,
    );
  }
}
