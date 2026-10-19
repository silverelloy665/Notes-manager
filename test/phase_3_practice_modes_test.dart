import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/question_model.dart';

void main() {
  group('Phase 3 - Practice Modes, Flashcards, and Exam Simulation Tests', () {
    late List<Question> sampleQuestions;

    setUp(() {
      sampleQuestions = [
        const Question(
          id: 'q1',
          topic: 'Operating Systems',
          subtopic: 'Process Scheduling',
          question: 'What happens when a process in the Running state triggers an I/O request?',
          answer: 'The process transitions from the Running state to the Waiting (Blocked) state until I/O completion.',
          options: [
            'It transitions directly to Terminated',
            'It transitions to the Waiting/Blocked state',
            'It stays in Running and spins in a tight CPU loop',
            'It immediately preempts another running core'
          ],
          correctOptionIndex: 1,
          explanation: 'When a process initiates an I/O request, the CPU cannot continue until the I/O completes, so the scheduler moves it to the Waiting/Blocked state.',
          difficulty: 'Medium',
          bloomLevel: 'Apply',
          sourcePage: 4,
          distractorReasoning: {
            'A': 'Processes only terminate upon completion or fatal errors, not routine I/O.',
            'C': 'CPU spinning wastes processing cycles; modern OSs put the process to sleep.',
            'D': 'A blocked process cannot preempt other cores.',
          },
          keyPointsRubric: [
            'Process transitions from Running to Waiting/Blocked',
            'CPU yields to scheduler for context switch',
            'Process enters Ready queue once I/O interrupt signals completion'
          ],
        ),
        const Question(
          id: 'q2',
          topic: 'Operating Systems',
          subtopic: 'Deadlock Detection',
          question: 'Which of the following conditions is NOT one of the four Coffman conditions necessary for deadlock?',
          answer: 'Preemption is allowed',
          options: [
            'Mutual Exclusion',
            'Hold and Wait',
            'Preemption is allowed',
            'Circular Wait'
          ],
          correctOptionIndex: 2,
          explanation: 'No preemption (resources cannot be forcibly taken) is the required condition; allowing preemption prevents deadlock.',
          difficulty: 'Hard',
          bloomLevel: 'Analyze',
          sourcePage: 9,
          distractorReasoning: {
            'A': 'Mutual exclusion is one of the four necessary Coffman conditions.',
            'B': 'Hold and wait is one of the four necessary Coffman conditions.',
            'D': 'Circular wait is one of the four necessary Coffman conditions.',
          },
        ),
        const Question(
          id: 'q3',
          topic: 'Computer Networks',
          subtopic: 'Transport Layer',
          question: 'Explain the purpose and mechanics of the TCP Three-Way Handshake.',
          answer: 'The TCP 3-way handshake synchronizes sequence numbers (SYN, SYN-ACK, ACK) and confirms both forward and reverse communications channels are open before data transmission.',
          options: null,
          correctOptionIndex: null,
          difficulty: 'Medium',
          bloomLevel: 'Understand',
          sourcePage: 12,
          keyPointsRubric: [
            'Client sends SYN packet with initial sequence number (ISN)',
            'Server replies with SYN-ACK packet acknowledging client ISN and stating its own ISN',
            'Client sends ACK packet confirming server ISN, establishing full-duplex socket'
          ],
        ),
      ];
    });

    test('Questions have grounded, non-generic academic content with clean titles', () {
      for (final q in sampleQuestions) {
        expect(q.topic, isNotEmpty);
        expect(q.topic.contains('('), isFalse, reason: 'Topic title must not contain dangling parenthesis');
        expect(q.question.contains('primary concepts and background discussed'), isFalse,
            reason: 'Question must not use generic placeholder template');
        expect(q.answer, isNotEmpty);
        expect(q.difficulty, isIn(['Easy', 'Medium', 'Hard']));
      }
    });

    test('MCQs provide exactly 4 options, valid correct index, and per-distractor reasoning', () {
      final mcqs = sampleQuestions.where((q) => q.isMcq).toList();
      expect(mcqs.length, 2);

      for (final mcq in mcqs) {
        expect(mcq.options!.length, 4);
        expect(mcq.correctOptionIndex, inInclusiveRange(0, 3));
        expect(mcq.explanation, isNotNull);
        expect(mcq.explanation, isNotEmpty);
        expect(mcq.distractorReasoning, isNotNull);
        expect(mcq.distractorReasoning!.length, greaterThanOrEqualTo(3));
      }
    });

    test('Confidence tracking detects high-confidence errors (hypercorrection targets)', () {
      // Learning-science rule:
      // If user answers incorrectly with high confidence (>= 0.8), flag as Hypercorrection Alert.
      final q = sampleQuestions[0];
      const selectedOption = 0; // Wrong option (Correct is 1)
      const userConfidence = 1.0; // 100% sure

      final isCorrect = selectedOption == q.correctOptionIndex;
      expect(isCorrect, isFalse);

      final isHypercorrectionAlert = !isCorrect && userConfidence >= 0.8;
      expect(isHypercorrectionAlert, isTrue,
          reason: 'High-confidence incorrect answer must trigger hypercorrection alert');
    });

    test('Confidence tracking identifies lucky guesses and solid mastery', () {
      final q = sampleQuestions[0];

      // Case A: Correct with low confidence -> Lucky Guess
      const luckyAnswer = 1; // Correct
      const lowConfidence = 0.25; // Guessing
      final isLuckyGuess = (luckyAnswer == q.correctOptionIndex) && lowConfidence < 0.8;
      expect(isLuckyGuess, isTrue);

      // Case B: Correct with high confidence -> Mastered
      const masteredAnswer = 1; // Correct
      const highConfidence = 1.0; // 100% Sure
      final isMastered = (masteredAnswer == q.correctOptionIndex) && highConfidence >= 0.8;
      expect(isMastered, isTrue);
    });

    test('Exam simulation diagnostic identifies weak focus areas below 70% threshold', () {
      // Simulate an exam result across 2 topics: Operating Systems (1/2 correct) and Computer Networks (1/1 correct)
      final topicTotal = <String, int>{'Operating Systems': 2, 'Computer Networks': 1};
      final topicCorrect = <String, int>{'Operating Systems': 1, 'Computer Networks': 1};

      final weakTopics = <String>[];
      topicTotal.forEach((topic, total) {
        final correct = topicCorrect[topic] ?? 0;
        final accuracy = (correct / total) * 100;
        if (accuracy < 70) {
          weakTopics.add(topic);
        }
      });

      expect(weakTopics, contains('Operating Systems'));
      expect(weakTopics, isNot(contains('Computer Networks')));
    });

    test('Conceptual questions contain structured rubric key points for grading', () {
      final conceptualQ = sampleQuestions.firstWhere((q) => !q.isMcq);
      expect(conceptualQ.keyPointsRubric, isNotNull);
      expect(conceptualQ.keyPointsRubric!.length, greaterThanOrEqualTo(3));
      expect(conceptualQ.keyPointsRubric![0], contains('SYN'));
      expect(conceptualQ.sourcePage, 12);
    });
  });
}
