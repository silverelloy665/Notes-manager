import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/spaced_repetition_service.dart';

void main() {
  group('Phase 5 - Spaced Repetition (SM-2) & Mastery Engine Suite', () {
    late SpacedRepetitionService srsService;
    final now = DateTime(2026, 4, 15, 10, 0);

    setUp(() {
      srsService = SpacedRepetitionService.instance;
    });

    test('SM-2 Progression: Rep 0 -> Rep 1 -> Rep 2 -> Rep 3', () {
      // 1st Review (Rep 0 -> 1) with Grade 4 (Good)
      final r1 = srsService.calculateSm2(
        currentInterval: 1,
        currentRepetitions: 0,
        currentEaseFactor: 2.5,
        grade: 4,
        reviewDate: now,
      );
      expect(r1.repetitions, 1);
      expect(r1.interval, 1);
      expect(r1.nextReviewDate, now.add(const Duration(days: 1)));
      expect(r1.ratingLabel, 'Good');

      // 2nd Review (Rep 1 -> 2) with Grade 4 (Good)
      final r2 = srsService.calculateSm2(
        currentInterval: r1.interval,
        currentRepetitions: r1.repetitions,
        currentEaseFactor: r1.easeFactor,
        grade: 4,
        reviewDate: r1.nextReviewDate,
      );
      expect(r2.repetitions, 2);
      expect(r2.interval, 6);
      expect(r2.nextReviewDate, r1.nextReviewDate.add(const Duration(days: 6)));

      // 3rd Review (Rep 2 -> 3) with Grade 4 (Good)
      final r3 = srsService.calculateSm2(
        currentInterval: r2.interval,
        currentRepetitions: r2.repetitions,
        currentEaseFactor: r2.easeFactor,
        grade: 4,
        reviewDate: r2.nextReviewDate,
      );
      expect(r3.repetitions, 3);
      expect(r3.interval, (6 * r2.easeFactor).round());
      expect(r3.interval, greaterThanOrEqualTo(14));
    });

    test('SM-2 Failure resets repetitions to 0 and interval to 1 day', () {
      final failedResult = srsService.calculateSm2(
        currentInterval: 18,
        currentRepetitions: 3,
        currentEaseFactor: 2.4,
        grade: 1, // Again
        reviewDate: now,
      );

      expect(failedResult.repetitions, 0);
      expect(failedResult.interval, 1);
      expect(failedResult.easeFactor, lessThan(2.4));
      expect(failedResult.ratingLabel, 'Again');
      expect(failedResult.nextReviewDate, now.add(const Duration(days: 1)));
    });

    test('SM-2 Ease factor does not drop below the minimum threshold of 1.3', () {
      double ef = 1.35;
      for (int i = 0; i < 5; i++) {
        final res = srsService.calculateSm2(
          currentInterval: 1,
          currentRepetitions: 0,
          currentEaseFactor: ef,
          grade: 0,
          reviewDate: now,
        );
        ef = res.easeFactor;
      }
      expect(ef, 1.3);
    });

    test('Confidence-derived grading aligns with hypercorrection learning science', () {
      // 1. Correct + 100% confidence -> Easy (grade 5)
      expect(srsService.gradeFromAccuracyAndConfidence(isCorrect: true, confidence: 1.0), 5);

      // 2. Correct + 50% confidence -> Good (grade 4)
      expect(srsService.gradeFromAccuracyAndConfidence(isCorrect: true, confidence: 0.50), 4);

      // 3. Correct + 25% confidence (Lucky guess) -> Hard (grade 3)
      expect(srsService.gradeFromAccuracyAndConfidence(isCorrect: true, confidence: 0.25), 3);

      // 4. Incorrect + 100% confidence (Hypercorrection error) -> Again (grade 1)
      expect(srsService.gradeFromAccuracyAndConfidence(isCorrect: false, confidence: 1.0), 1);

      // 5. Incorrect + Low confidence -> Again (grade 2)
      expect(srsService.gradeFromAccuracyAndConfidence(isCorrect: false, confidence: 0.50), 2);
    });

    test('MasteryLevel accurately identifies reviewDue, mastered, learning, and new cards', () {
      final overdueQ = Question(
        id: 'q1',
        topic: 'OS',
        question: 'What is PCB?',
        answer: 'Data structure',
        nextReviewDate: now.subtract(const Duration(days: 2)),
      );
      expect(srsService.getMasteryLevel(overdueQ, now: now), MasteryLevel.reviewDue);

      final masteredQ = Question(
        id: 'q2',
        topic: 'OS',
        question: 'What is deadlock?',
        answer: 'Permanent block',
        srsRepetitions: 3,
        srsInterval: 24,
        nextReviewDate: now.add(const Duration(days: 20)),
      );
      expect(srsService.getMasteryLevel(masteredQ, now: now), MasteryLevel.mastered);

      final learningQ = Question(
        id: 'q3',
        topic: 'OS',
        question: 'What is paging?',
        answer: 'Memory scheme',
        srsRepetitions: 1,
        srsInterval: 1,
        lastScore: 1.0,
        nextReviewDate: now.add(const Duration(days: 1)),
      );
      expect(srsService.getMasteryLevel(learningQ, now: now), MasteryLevel.learning);

      final newQ = const Question(
        id: 'q4',
        topic: 'OS',
        question: 'What is semaphore?',
        answer: 'Signaling mechanism',
      );
      expect(srsService.getMasteryLevel(newQ, now: now), MasteryLevel.newCard);
    });

    test('Mastery dashboard calculation summarizes accuracy, coverage, and flags weak topics', () {
      final questions = [
        Question(
          id: 'q1',
          topic: 'Operating Systems',
          question: 'Q1',
          answer: 'A1',
          srsRepetitions: 3,
          srsInterval: 25,
          lastScore: 1.0,
        ),
        Question(
          id: 'q2',
          topic: 'Operating Systems',
          question: 'Q2',
          answer: 'A2',
          srsRepetitions: 2,
          srsInterval: 6,
          lastScore: 1.0,
        ),
        Question(
          id: 'q3',
          topic: 'Computer Networks',
          question: 'Q3',
          answer: 'A3',
          srsRepetitions: 0,
          srsInterval: 1,
          lastScore: 0.0, // Failed
        ),
        Question(
          id: 'q4',
          topic: 'Computer Networks',
          question: 'Q4',
          answer: 'A4',
          srsRepetitions: 0,
          srsInterval: 1,
          lastScore: 0.5, // 50%
        ),
        const Question(
          id: 'q5',
          topic: 'Databases',
          question: 'Q5',
          answer: 'A5',
        ), // Unattempted
      ];

      final dashboard = srsService.calculateDashboardData(
        questions: questions,
        studyStreakDays: 5,
        totalMinutesSpent: 65,
        now: now,
      );

      expect(dashboard.totalQuestions, 5);
      expect(dashboard.attemptedQuestions, 4);
      expect(dashboard.coveragePercentage, 80.0);
      expect(dashboard.masteredCount, 1);
      expect(dashboard.studyStreakDays, 5);
      expect(dashboard.totalMinutesSpent, 65);

      // Computer Networks has 25% average accuracy, should be flagged as weak
      expect(dashboard.weakTopics, contains('Computer Networks'));
      expect(dashboard.weakTopics, isNot(contains('Operating Systems')));
    });

    test('Adaptive queue interleaves 60% due/weak items and 40% new items', () {
      final pool = [
        // 2 Due/Weak items
        Question(
          id: 'due1',
          topic: 'OS',
          question: 'Due 1',
          answer: 'A',
          nextReviewDate: now.subtract(const Duration(days: 3)),
          lastScore: 0.0,
        ),
        Question(
          id: 'due2',
          topic: 'OS',
          question: 'Due 2',
          answer: 'A',
          nextReviewDate: now.subtract(const Duration(days: 1)),
          lastScore: 0.5,
        ),
        // 3 New items
        const Question(id: 'new1', topic: 'OS', question: 'New 1', answer: 'A'),
        const Question(id: 'new2', topic: 'OS', question: 'New 2', answer: 'A'),
        const Question(id: 'new3', topic: 'OS', question: 'New 3', answer: 'A'),
      ];

      final adaptiveQueue = srsService.generateAdaptiveQueue(
        pool,
        targetCount: 4,
        now: now,
      );

      expect(adaptiveQueue.length, 4);
      // Contains due items
      expect(adaptiveQueue.any((q) => q.id.startsWith('due')), isTrue);
      // Contains new items
      expect(adaptiveQueue.any((q) => q.id.startsWith('new')), isTrue);
    });

    test('Anki-style interval previews are properly projected', () {
      final previews = srsService.previewNextIntervals(
        currentInterval: 6,
        currentRepetitions: 2,
        currentEaseFactor: 2.5,
      );

      expect(previews['Again'], 1);
      expect(previews['Hard'], greaterThanOrEqualTo(1));
      expect(previews['Good'], (6 * 2.5).round());
      expect(previews['Easy'], greaterThan(previews['Good']!));
    });
  });
}
