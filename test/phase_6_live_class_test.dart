import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/models/live_class_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 6 - Classroom Live Classes & Jitsi Integration Tests', () {
    test('StudentAttendanceRecord model serialization and deserialization', () {
      final joinedTime = DateTime(2026, 10, 21, 10, 5, 0);
      final leftTime = DateTime(2026, 10, 21, 10, 50, 0);

      final record = StudentAttendanceRecord(
        studentId: 'stud_777',
        studentName: 'Aarush Patel',
        studentEmail: 'aarush@example.com',
        joinedAt: joinedTime,
        leftAt: leftTime,
        durationSeconds: 2700,
      );

      final map = record.toMap();
      expect(map['studentId'], 'stud_777');
      expect(map['studentName'], 'Aarush Patel');
      expect(map['durationSeconds'], 2700);

      final fromMap = StudentAttendanceRecord.fromMap(map);
      expect(fromMap.studentId, 'stud_777');
      expect(fromMap.studentName, 'Aarush Patel');
      expect(fromMap.durationSeconds, 2700);
    });

    test('LiveClassSession model computed properties and roundtrip serialization', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 35));
      final endTime = DateTime.now();

      final session = LiveClassSession(
        id: 'live_sess_01',
        classroomId: 'cls_dev_os',
        title: 'Virtual Memory & Page Replacement',
        unitNumber: 4,
        unitTitle: 'Paging Algorithms',
        roomName: 'StudyMate_YM5PKF_928172',
        hostTeacherId: 'teacher_os_1',
        hostTeacherName: 'Prof. Tanenbaum',
        isOngoing: false,
        startedAt: startTime,
        endedAt: endTime,
        notes: 'Covered LRU and FIFO algorithms. Recording available.',
        attendanceRecords: {
          'stud_1': StudentAttendanceRecord(
            studentId: 'stud_1',
            studentName: 'Alice Smith',
            studentEmail: 'alice@uni.edu',
            joinedAt: startTime.add(const Duration(minutes: 2)),
            durationSeconds: 1980,
          ),
          'stud_2': StudentAttendanceRecord(
            studentId: 'stud_2',
            studentName: 'Bob Jones',
            studentEmail: 'bob@uni.edu',
            joinedAt: startTime.add(const Duration(minutes: 5)),
            durationSeconds: 1800,
          ),
        },
      );

      // Verify computed meetUrl
      expect(session.meetUrl, 'https://meet.jit.si/StudyMate_YM5PKF_928172');
      expect(session.durationMinutes, greaterThanOrEqualTo(34));
      expect(session.attendanceRecords.length, 2);

      final map = session.toMap();
      expect(map['classroomId'], 'cls_dev_os');
      expect(map['title'], contains('Virtual Memory'));
      expect(map['isOngoing'], false);
      expect(map['roomName'], 'StudyMate_YM5PKF_928172');
      expect((map['attendanceRecords'] as Map).containsKey('stud_1'), true);

      final restored = LiveClassSession.fromMap(map, 'live_sess_01', classroomId: 'cls_dev_os');
      expect(restored.id, 'live_sess_01');
      expect(restored.title, 'Virtual Memory & Page Replacement');
      expect(restored.meetUrl, 'https://meet.jit.si/StudyMate_YM5PKF_928172');
      expect(restored.attendanceRecords.length, 2);
      expect(restored.attendanceRecords['stud_2']?.studentName, 'Bob Jones');
    });

    test('ExportService generates well-formatted attendance CSV report', () {
      final session = LiveClassSession(
        id: 'sess_csv_test',
        classroomId: 'cls_1',
        title: 'Midterm Review',
        roomName: 'StudyMate_ROOM_1',
        hostTeacherId: 't1',
        hostTeacherName: 'Teacher',
        isOngoing: false,
        startedAt: DateTime(2026, 10, 21, 14, 0),
        attendanceRecords: {
          's1': StudentAttendanceRecord(
            studentId: 's1',
            studentName: 'Alice Smith',
            studentEmail: 'alice@school.edu',
            joinedAt: DateTime(2026, 10, 21, 14, 2),
            durationSeconds: 2700,
          ),
        },
      );

      final enrolled = [
        const StudentGradeSummary(
          studentId: 's1',
          studentName: 'Alice Smith',
          studentEmail: 'alice@school.edu',
          studentPhone: '111',
          totalObtained: 90,
          totalMax: 100,
          assessmentsCount: 1,
        ),
        const StudentGradeSummary(
          studentId: 's2',
          studentName: 'Charlie Brown',
          studentEmail: 'charlie@school.edu',
          studentPhone: '222',
          totalObtained: 80,
          totalMax: 100,
          assessmentsCount: 1,
        ),
      ];

      final csv = ExportService.instance.generateAttendanceCsv(
        session: session,
        enrolledStudents: enrolled,
      );

      expect(csv, contains('Student ID,Student Name,Student Email,Status,Joined At,Duration (Minutes)'));
      expect(csv, contains('s1,Alice Smith,alice@school.edu,Present'));
      expect(csv, contains('s2,Charlie Brown,charlie@school.edu,Absent'));
    });
  });
}
