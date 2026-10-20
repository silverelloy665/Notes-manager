import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 3 - Question Bank & CSV Pipeline Tests', () {
    test('Question model serialization and deserialization preserves all Phase 3 fields', () {
      final now = DateTime(2026, 10, 20, 16, 0);
      final question = Question(
        id: 'q_phase3_101',
        topic: 'Operating Systems',
        question: 'What is the primary advantage of the Round Robin CPU scheduling algorithm?',
        answer: 'It provides fairness by giving each ready process a finite time quantum.',
        classroomId: 'cls_test_42',
        unitNumber: 2,
        questionType: 'mcq',
        difficulty: 'Medium',
        bloomLevel: 'Understand',
        marks: 2.0,
        negativeMarks: 0.5,
        options: [
          'It eliminates context switching overhead completely',
          'It provides fairness by giving each ready process a finite time quantum',
          'It guarantees the lowest possible turnaround time for CPU-bound jobs',
          'It uses static priority queues without preemption',
        ],
        correctOptionIndex: 1,
        explanation: 'Round Robin ensures starvation-free time-sharing across interactive tasks.',
        distractorReasoning: {
          'A': 'Context switches actually occur frequently at every time slice expiration.',
          'C': 'SJF or SRTF achieves minimum average turnaround time, not Round Robin.',
          'D': 'Round Robin is preemptive, triggered by timer interrupts.',
        },
        keyPointsRubric: [
          'Explains time slice quantum',
          'Highlights preemption',
          'Notes starvation freedom',
        ],
        tags: ['OS', 'CPU Scheduling', 'Round Robin'],
        isAiGenerated: true,
        sourcePage: 14,
        documentId: 'doc_cpu_slides_v2',
        createdAt: now,
      );

      final map = question.toMap();
      expect(map['question'], contains('Round Robin'));
      expect(map['classroomId'], 'cls_test_42');
      expect(map['unitNumber'], 2);
      expect(map['questionType'], 'mcq');
      expect(map['marks'], 2.0);
      expect(map['negativeMarks'], 0.5);
      expect(map['isAiGenerated'], true);
      expect(map['tags'], contains('Round Robin'));
      expect(map['options'], hasLength(4));

      final restored = Question.fromMap(map, 'q_phase3_101');
      expect(restored.id, 'q_phase3_101');
      expect(restored.topic, 'Operating Systems');
      expect(restored.classroomId, 'cls_test_42');
      expect(restored.unitNumber, 2);
      expect(restored.questionType, 'mcq');
      expect(restored.marks, 2.0);
      expect(restored.negativeMarks, 0.5);
      expect(restored.correctOptionIndex, 1);
      expect(restored.options?[1], contains('finite time quantum'));
      expect(restored.isAiGenerated, true);
      expect(restored.distractorReasoning?['A'], contains('Context switches'));
      expect(restored.keyPointsRubric, hasLength(3));
      expect(restored.sourcePage, 14);
    });

    test('ExportService generates and parses Question Bank CSV accurately', () {
      final questions = [
        const Question(
          id: 'q1',
          topic: 'Computer Networks',
          unitNumber: 1,
          questionType: 'mcq',
          difficulty: 'Easy',
          bloomLevel: 'Remember',
          marks: 1.0,
          negativeMarks: 0.0,
          question: 'Which OSI layer does the IP protocol operate on?',
          answer: 'Network Layer',
          options: ['Data Link Layer', 'Network Layer', 'Transport Layer', 'Application Layer'],
          correctOptionIndex: 1,
          explanation: 'IPv4 and IPv6 provide host-to-host addressing at Layer 3.',
          tags: ['Networks', 'OSI', 'IP'],
          sourcePage: 5,
        ),
        const Question(
          id: 'q2',
          topic: 'Computer Networks',
          unitNumber: 2,
          questionType: 'short',
          difficulty: 'Hard',
          bloomLevel: 'Analyze',
          marks: 5.0,
          negativeMarks: 0.0,
          question: 'Explain why TCP connection teardown requires a four-way handshake.',
          answer: 'Because TCP connections are full-duplex, each direction of data flow must be terminated independently with FIN and ACK packets.',
          explanation: 'Half-closed state allows remaining data transmission before both endpoints close.',
          tags: ['TCP', 'Handshake'],
          sourcePage: 28,
        ),
      ];

      final csvString = ExportService.instance.generateQuestionBankCsv(questions);
      expect(csvString, contains('Topic,Unit,Type,Difficulty,Bloom,Marks,Negative Marks'));
      expect(csvString, contains('Which OSI layer does the IP protocol operate on?'));
      expect(csvString, contains('Explain why TCP connection teardown'));

      final parsed = ExportService.instance.parseQuestionBankCsv(csvString, classroomId: 'test_cls');
      expect(parsed, hasLength(2));

      final q1 = parsed[0];
      expect(q1.topic, 'Computer Networks');
      expect(q1.unitNumber, 1);
      expect(q1.questionType, 'mcq');
      expect(q1.difficulty, 'Easy');
      expect(q1.marks, 1.0);
      expect(q1.options, hasLength(4));
      expect(q1.correctOptionIndex, 1); // Option B -> index 1

      final q2 = parsed[1];
      expect(q2.questionType, 'short');
      expect(q2.difficulty, 'Hard');
      expect(q2.marks, 5.0);
      expect(q2.question, contains('four-way handshake'));
      expect(q2.answer, contains('full-duplex'));
    });
  });
}
