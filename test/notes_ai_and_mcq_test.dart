import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';

void main() {
  group('MCQ Flashcard Model & AI Generation Test Suite', () {
    test('Question model properly serializes and deserializes MCQ fields', () {
      final question = Question(
        id: 'q1',
        topic: 'Software Engineering',
        question: 'What is the primary benefit of loose coupling in system architecture?',
        answer: 'High maintainability and independent module testing.',
        options: [
          'High maintainability and independent module testing',
          'Tightly binding UI to database queries',
          'Eliminating the need for code review',
          'Forcing all state into global variables',
        ],
        correctOptionIndex: 0,
        explanation: 'Loose coupling isolates component dependencies, allowing independent development and testing.',
      );

      expect(question.isMcq, isTrue);

      final map = question.toMap();
      expect(map['options'], hasLength(4));
      expect(map['correctOptionIndex'], equals(0));
      expect(map['explanation'], contains('Loose coupling isolates component dependencies'));

      final restored = Question.fromMap(map, 'q1');
      expect(restored.isMcq, isTrue);
      expect(restored.options, equals(question.options));
      expect(restored.correctOptionIndex, equals(0));
      expect(restored.explanation, equals(question.explanation));
    });

    test('NotesAiService generates comprehensive practice questions with properly framed academic titles and MCQs', () async {
      const samplePresentationText = '''
Assignment (Research Activity)
Last Date of Submission: 18/10/2026
INSTRUCTIONS:
1. Select any topic from Software Engineering domain
2. Formulate Problem Statements
3. Formulate Objectives
4. Advantages/Disadvantages of proposed/implemented method s
5. Analysis of findings
6. Conclusion and recommendations
7. References / APA format
''';

      final sections = [
        const DocumentSection(
          title: 'Assignment (',
          content: 'Last Date of Submission: 18/10/2026\nINSTRUCTIONS: 1. Select any topic from Software Engineering domain',
        ),
        const DocumentSection(
          title: '2. Formulate Problem Statements',
          content: 'Identify core technical challenges and boundary conditions.',
        ),
        const DocumentSection(
          title: '3. Formulate Objectives',
          content: 'Establish SMART objectives directly mapping to the problem statement.',
        ),
        const DocumentSection(
          title: '4. Advantages/Disadvantages of proposed/implemented method s',
          content: 'Evaluate architectural trade-offs, complexity, and performance baselines.',
        ),
        const DocumentSection(
          title: '5. Analysis of findings',
          content: 'Analyze quantitative empirical data and distributions.',
        ),
        const DocumentSection(
          title: '6. Conclusion and recommendations',
          content: 'Synthesize outcomes and propose practical deployment recommendations.',
        ),
      ];

      final questions = await NotesAiService.instance.generatePracticeQuestions(
        text: samplePresentationText,
        title: 'Assignment (Research Activity)',
        topic: 'Software Engineering',
        sections: sections,
        count: 15,
      );

      // Verify that significantly more questions are generated (>= 15)
      expect(questions.length, greaterThanOrEqualTo(15));

      // Verify that MCQs are generated alongside conceptual Q&As
      final mcqs = questions.where((q) => q.isMcq).toList();
      final conceptuals = questions.where((q) => !q.isMcq).toList();

      expect(mcqs.length, greaterThanOrEqualTo(8));
      expect(conceptuals.length, greaterThanOrEqualTo(5));

      // Verify that questions are well-framed without awkward fragments
      for (final q in questions) {
        expect(q.question, isNot(contains('In the topic "Assignment ("')));
        expect(q.question, isNot(contains('In the context of Assignment (')));
        expect(q.question, isNot(contains('method s')));

        if (q.isMcq) {
          expect(q.options, hasLength(4));
          expect(q.correctOptionIndex, inInclusiveRange(0, 3));
          expect(q.explanation, isNotNull);
          expect(q.explanation!.isNotEmpty, isTrue);
        }
      }
    });

    test('FirestoreService batch saves questions with MCQ options and persists correctly', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final firestoreService = FirestoreService(firestore: fakeFirestore, auth: null);

      final batch = [
        (
          topic: 'Software Engineering',
          question: 'What is the primary role of regression testing?',
          answer: 'Ensuring recent updates have not broken existing functionality.',
          subjectId: null,
          unitId: null,
          options: [
            'Ensuring recent updates have not broken existing functionality',
            'Rewriting code from scratch',
            'Bypassing automated test suites',
            'Generating random mock data',
          ],
          correctOptionIndex: 0,
          explanation: 'Regression testing prevents regression defects when code changes.',
        ),
      ];

      final created = await firestoreService.createQuestionsBatch(
        questions: batch,
        createdBy: 'test_student',
      );

      expect(created, hasLength(1));
      expect(created.first.isMcq, isTrue);
      expect(created.first.options, hasLength(4));
      expect(created.first.correctOptionIndex, equals(0));
      expect(created.first.explanation, contains('Regression testing prevents'));
    });
  });
}

