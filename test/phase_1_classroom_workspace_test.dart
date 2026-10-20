import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/announcement_model.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 1 - Classroom Workspace Shell Tests', () {
    test('Classroom model serializes and deserializes new Phase 1 settings correctly', () {
      final classroom = Classroom(
        id: 'cls_123',
        teacherId: 'teacher_999',
        teacherName: 'Prof. Turing',
        name: 'Operating Systems CE',
        subject: 'Computer Science',
        code: 'OS301A',
        studentIds: const ['std_1', 'std_2'],
        description: 'Semester 5 Core Course',
        isJoiningEnabled: false,
        requireApproval: true,
        pendingStudentIds: const ['std_3', 'std_4'],
        coTeacherIds: const ['teacher_888'],
        isArchived: true,
      );

      final map = classroom.toMap();
      expect(map['name'], 'Operating Systems CE');
      expect(map['code'], 'OS301A');
      expect(map['description'], 'Semester 5 Core Course');
      expect(map['isJoiningEnabled'], false);
      expect(map['requireApproval'], true);
      expect(map['pendingStudentIds'], ['std_3', 'std_4']);
      expect(map['coTeacherIds'], ['teacher_888']);
      expect(map['isArchived'], true);

      final restored = Classroom.fromMap(map, 'cls_123');
      expect(restored.id, 'cls_123');
      expect(restored.name, 'Operating Systems CE');
      expect(restored.isJoiningEnabled, false);
      expect(restored.requireApproval, true);
      expect(restored.pendingCount, 2);
      expect(restored.isArchived, true);
    });

    test('Announcement and AnnouncementComment model round-trip', () {
      final announcement = Announcement(
        id: 'ann_1',
        classroomId: 'cls_123',
        authorId: 'teacher_999',
        authorName: 'Prof. Turing',
        authorRole: 'Teacher',
        content: 'Welcome to Operating Systems! Review Unit 1 notes before Tuesday.',
        attachments: const [
          AnnouncementAttachment(name: 'Syllabus PDF', url: 'https://example.com/syllabus.pdf', type: 'file'),
          AnnouncementAttachment(name: 'Course Intro Video', url: 'https://youtube.com/watch?v=123', type: 'link'),
        ],
        pinned: true,
        commentCount: 2,
        createdAt: DateTime(2026, 10, 20, 10, 0),
      );

      final map = announcement.toMap();
      expect(map['content'], contains('Welcome to Operating Systems'));
      expect(map['pinned'], true);
      expect(map['attachments'], hasLength(2));

      final restored = Announcement.fromMap(map, 'ann_1');
      expect(restored.isTeacherPost, true);
      expect(restored.pinned, true);
      expect(restored.attachments.length, 2);
      expect(restored.attachments.first.type, 'file');

      final comment = AnnouncementComment(
        id: 'c_1',
        announcementId: 'ann_1',
        authorId: 'std_1',
        authorName: 'Ada Lovelace',
        authorRole: 'Student',
        content: 'Will this lecture be recorded?',
        createdAt: DateTime(2026, 10, 20, 11, 0),
      );

      final commentMap = comment.toMap();
      final restoredComment = AnnouncementComment.fromMap(commentMap, 'c_1');
      expect(restoredComment.authorName, 'Ada Lovelace');
      expect(restoredComment.content, 'Will this lecture be recorded?');
    });

    test('Roster CSV export formats student data and header correctly', () {
      final classroom = Classroom(
        id: 'cls_123',
        teacherId: 'teacher_999',
        teacherName: 'Prof. Turing',
        name: 'Operating Systems CE',
        subject: 'Computer Science',
        code: 'OS301A',
        studentIds: const ['std_1', 'std_2'],
      );

      final students = [
        const StudentGradeSummary(
          studentId: 'std_1',
          studentName: 'Ada Lovelace',
          studentEmail: 'ada@example.com',
          studentPhone: '+1-555-0101',
          totalObtained: 95.0,
          totalMax: 100.0,
          assessmentsCount: 2,
        ),
        const StudentGradeSummary(
          studentId: 'std_2',
          studentName: 'Charles Babbage',
          studentEmail: 'charles@example.com',
          studentPhone: '+1-555-0102',
          totalObtained: 80.0,
          totalMax: 100.0,
          assessmentsCount: 2,
        ),
      ];

      final csv = ExportService.instance.generateRosterCsv(classroom, students);

      expect(csv, contains('Classroom Name,"Operating Systems CE"'));
      expect(csv, contains('Join Code,OS301A'));
      expect(csv, contains('Ada Lovelace'));
      expect(csv, contains('ada@example.com'));
      expect(csv, contains('95.0%'));
      expect(csv, contains('Charles Babbage'));
      expect(csv, contains('80.0%'));
    });
  });
}
