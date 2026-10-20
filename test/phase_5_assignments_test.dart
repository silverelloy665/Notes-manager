import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/assignment_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 5 - Classroom Assignments & Rubrics Tests', () {
    test('Assignment model serialization and deserialization preserves rubrics and late policies', () {
      final now = DateTime(2026, 10, 20, 19, 0);
      final due = now.add(const Duration(days: 5));

      final assignment = Assignment(
        id: 'assign_101',
        classroomId: 'cls_dev_1',
        title: 'Project 1: Multithreaded Web Server',
        unitNumber: 3,
        instructions: 'Implement a POSIX socket server handling concurrent HTTP GET requests using thread pools.',
        totalPoints: 100.0,
        dueDate: due,
        allowLateSubmissions: true,
        latePenaltyPercentPerDay: 10.0,
        rubricCriteria: const [
          AssignmentRubricCriterion(
            title: 'Socket Architecture & Concurrency',
            description: 'Properly synchronizes thread pool workers without race conditions.',
            maxPoints: 50.0,
          ),
          AssignmentRubricCriterion(
            title: 'HTTP Protocol Parsing & Headers',
            description: 'Parses HTTP/1.1 request lines, status codes, and MIME types.',
            maxPoints: 30.0,
          ),
          AssignmentRubricCriterion(
            title: 'Error Handling & Performance',
            description: 'Handles SIGPIPE, 404, 500 cleanly with bench test logs.',
            maxPoints: 20.0,
          ),
        ],
        referenceAttachments: const [
          AssignmentAttachment(
            fileName: 'http_spec.pdf',
            fileUrl: 'https://example.com/http_spec.pdf',
            fileType: 'pdf',
            fileSizeBytes: 524288,
          ),
        ],
        status: 'published',
        createdAt: now,
      );

      final map = assignment.toMap();
      expect(map['title'], contains('Multithreaded Web Server'));
      expect(map['totalPoints'], 100.0);
      expect(map['allowLateSubmissions'], true);
      expect(map['latePenaltyPercentPerDay'], 10.0);
      expect(map['rubricCriteria'], hasLength(3));
      expect(map['referenceAttachments'], hasLength(1));

      final restored = Assignment.fromMap(map, 'assign_101', classroomId: 'cls_dev_1');
      expect(restored.id, 'assign_101');
      expect(restored.title, contains('Multithreaded Web Server'));
      expect(restored.unitNumber, 3);
      expect(restored.rubricCriteria, hasLength(3));
      expect(restored.rubricCriteria.first.title, 'Socket Architecture & Concurrency');
      expect(restored.rubricCriteria.first.maxPoints, 50.0);
      expect(restored.referenceAttachments.first.fileName, 'http_spec.pdf');
      expect(restored.isPastDue, false);
      expect(restored.dueRelativeText, contains('Due in 4') | contains('Due in 5'));
    });

    test('AssignmentSubmission model and CSV export pipeline', () {
      final now = DateTime(2026, 10, 20, 20, 0);
      final assignment = Assignment(
        id: 'assign_101',
        classroomId: 'cls_dev_1',
        title: 'Project 1: Multithreaded Web Server',
        dueDate: now.add(const Duration(days: 3)),
        instructions: 'Build web server',
        totalPoints: 100.0,
      );

      final submission = AssignmentSubmission(
        id: 'sub_student_7',
        assignmentId: 'assign_101',
        classroomId: 'cls_dev_1',
        studentId: 'student_7',
        studentName: 'Bob Builder',
        studentEmail: 'bob@example.edu',
        submittedFiles: const [
          AssignmentAttachment(
            fileName: 'server.c',
            fileUrl: 'file://server.c',
            fileType: 'c',
            fileSizeBytes: 12400,
          ),
        ],
        textResponse: 'Completed thread pool implementation using pthread_cond.',
        submittedAt: now,
        isLate: false,
        pointsAwarded: 95.0,
        maxPoints: 100.0,
        rubricScores: {
          'Socket Architecture & Concurrency': 48.0,
          'HTTP Protocol Parsing & Headers': 28.0,
          'Error Handling & Performance': 19.0,
        },
        feedback: 'Excellent synchronization logic and clean thread-safe queue.',
        status: 'graded',
      );

      final map = submission.toMap();
      expect(map['studentName'], 'Bob Builder');
      expect(map['pointsAwarded'], 95.0);
      expect(map['status'], 'graded');
      expect(map['rubricScores'], containsPair('Error Handling & Performance', 19.0));

      final restored = AssignmentSubmission.fromMap(map, 'sub_student_7', classroomId: 'cls_dev_1', assignmentId: 'assign_101');
      expect(restored.id, 'sub_student_7');
      expect(restored.studentName, 'Bob Builder');
      expect(restored.pointsAwarded, 95.0);
      expect(restored.isGraded, true);

      // Verify CSV export
      final csv = ExportService.instance.generateAssignmentGradesCsv(assignment, [restored]);
      expect(csv, contains('Assignment Title,Project 1: Multithreaded Web Server'));
      expect(csv, contains('Bob Builder'));
      expect(csv, contains('bob@example.edu'));
      expect(csv, contains('95.0'));
      expect(csv, contains('Excellent synchronization logic'));
    });
  });
}
