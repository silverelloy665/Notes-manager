import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/exam_model.dart';
import 'package:studymate_classroom/models/question_model.dart';

void main() {
  group('Phase 4 - Classroom Exams & Assessments Tests', () {
    test('Exam model serialization and deserialization preserves proctoring and questions', () {
      final now = DateTime(2026, 10, 20, 18, 0);
      final exam = Exam(
        id: 'exam_101',
        classroomId: 'cls_os_1',
        title: 'Operating Systems Midterm Assessment',
        subject: 'Operating Systems',
        unitNumber: 2,
        durationMinutes: 45,
        passingMarks: 18.0,
        totalMarks: 50.0,
        instructions: 'Read each prompt carefully. Tab switches are strictly monitored.',
        fullScreenEnforced: true,
        tabSwitchLimit: 3,
        disableCopyPaste: true,
        allowCalculator: true,
        watermarkStudentId: true,
        shuffleQuestions: true,
        shuffleOptions: true,
        releaseScoresImmediately: true,
        isPublished: true,
        questions: const [
          Question(
            id: 'q_os_1',
            topic: 'Operating Systems',
            unitNumber: 2,
            questionType: 'mcq',
            question: 'Which page replacement algorithm suffers from Belady anomaly?',
            answer: 'FIFO',
            options: ['FIFO', 'LRU', 'Optimal', 'Clock'],
            correctOptionIndex: 0,
            marks: 2.0,
            negativeMarks: 0.5,
          ),
          Question(
            id: 'q_os_2',
            topic: 'Operating Systems',
            unitNumber: 2,
            questionType: 'true_false',
            question: 'Thrashing occurs when a process spends more time paging than executing.',
            answer: 'True',
            marks: 1.0,
          ),
        ],
        createdAt: now,
      );

      final map = exam.toMap();
      expect(map['title'], 'Operating Systems Midterm Assessment');
      expect(map['durationMinutes'], 45);
      expect(map['tabSwitchLimit'], 3);
      expect(map['fullScreenEnforced'], true);
      expect(map['questions'], hasLength(2));

      final restored = Exam.fromMap(map, 'exam_101', classroomId: 'cls_os_1');
      expect(restored.id, 'exam_101');
      expect(restored.classroomId, 'cls_os_1');
      expect(restored.durationMinutes, 45);
      expect(restored.passingMarks, 18.0);
      expect(restored.tabSwitchLimit, 3);
      expect(restored.questions, hasLength(2));
      expect(restored.questions.first.question, contains('Belady'));
      expect(restored.questions.first.options?.first, 'FIFO');
    });

    test('ExamSubmission model accurately tracks answers, scores, and tab-switch integrity logs', () {
      final now = DateTime(2026, 10, 20, 18, 30);
      final submission = ExamSubmission(
        id: 'sub_student_1',
        examId: 'exam_101',
        classroomId: 'cls_os_1',
        studentId: 'student_42',
        studentName: 'Alice Kumar',
        studentEmail: 'alice@example.edu',
        answers: {
          'q_os_1': 0, // Picked FIFO -> correct (+2.0)
          'q_os_2': 'True', // Picked True -> correct (+1.0)
        },
        questionScores: {
          'q_os_1': 2.0,
          'q_os_2': 1.0,
        },
        questionFeedback: {
          'q_os_1': 'Correct! Full marks.',
          'q_os_2': 'Accurate definition.',
        },
        flaggedQuestionIds: ['q_os_1'],
        tabSwitchCount: 1,
        tabSwitchLogs: [now.subtract(const Duration(minutes: 10))],
        startedAt: now.subtract(const Duration(minutes: 30)),
        submittedAt: now,
        totalMarksObtained: 3.0,
        maxMarks: 3.0,
        percentage: 100.0,
        isPassed: true,
        status: 'released',
      );

      final map = submission.toMap();
      expect(map['studentName'], 'Alice Kumar');
      expect(map['totalMarksObtained'], 3.0);
      expect(map['percentage'], 100.0);
      expect(map['tabSwitchCount'], 1);
      expect(map['status'], 'released');

      final restored = ExamSubmission.fromMap(map, 'sub_student_1', classroomId: 'cls_os_1', examId: 'exam_101');
      expect(restored.id, 'sub_student_1');
      expect(restored.studentId, 'student_42');
      expect(restored.answers['q_os_1'], 0);
      expect(restored.totalMarksObtained, 3.0);
      expect(restored.isPassed, true);
      expect(restored.tabSwitchLogs, hasLength(1));
    });
  });
}
