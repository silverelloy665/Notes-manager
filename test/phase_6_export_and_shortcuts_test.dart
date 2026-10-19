import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/summary_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 6 - Export Service & Keyboard Shortcuts Tests', () {
    final sampleQuestions = [
      const Question(
        id: 'q1',
        topic: 'Operating Systems',
        subtopic: 'Deadlock Detection',
        question: 'What four conditions are necessary for deadlock to occur?',
        answer: 'Mutual exclusion, Hold and wait, No preemption, Circular wait.',
        difficulty: 'Medium',
        bloomLevel: 'Understand',
        sourcePage: 3,
        supportingExcerpt: 'Deadlock requires mutual exclusion, hold and wait, no preemption, and circular wait.',
        keyPointsRubric: [
          'Mutual exclusion condition',
          'Hold and wait condition',
          'No preemption condition',
          'Circular wait condition',
        ],
      ),
      const Question(
        id: 'q2',
        topic: 'Operating Systems',
        subtopic: 'Deadlock Prevention',
        question: 'Which deadlock prevention technique eliminates the Circular Wait condition?',
        answer: 'Imposing a total ordering of all resource types and requiring processes to request in increasing order.',
        difficulty: 'Hard',
        bloomLevel: 'Analyze',
        sourcePage: 5,
        options: [
          'Preempting resources from holding processes',
          'Imposing a strict global resource ordering',
          'Allocating all resources at once before execution',
          'Using banker algorithm safety checks',
        ],
        correctOptionIndex: 1,
        explanation: 'Resource ordering ensures cycles cannot form in the resource allocation graph.',
        distractorReasoning: {
          '0': 'Preemption eliminates the no-preemption condition, not circular wait.',
          '2': 'Allocating all resources eliminates hold-and-wait.',
          '3': 'Banker algorithm is an avoidance technique, not prevention.',
        },
      ),
    ];

    test('TC-P6-1: Generates valid Anki CSV with Tab separation and HTML formatting', () {
      final ankiCsv = ExportService.instance.generateAnkiCsv(sampleQuestions);

      expect(ankiCsv, contains('#separator:Tab'));
      expect(ankiCsv, contains('#html:true'));
      expect(ankiCsv, contains('#tags column:3'));

      // Check MCQ card
      expect(ankiCsv, contains('Deadlock Prevention'));
      expect(ankiCsv, contains('<b>B)</b> Imposing a strict global resource ordering'));
      expect(ankiCsv, contains('Resource ordering ensures cycles cannot form'));
      expect(ankiCsv, contains('Operating_Systems::Deadlock_Prevention'));
      expect(ankiCsv, contains('Hard'));
      expect(ankiCsv, contains('Analyze'));

      // Check Conceptual card
      expect(ankiCsv, contains('Mutual exclusion condition'));
      expect(ankiCsv, contains('Operating_Systems::Deadlock_Detection'));
    });

    test('TC-P6-2: Generates valid printable PDF study sheet with question sheet and answer key', () async {
      final pdfBytes = await ExportService.instance.generateStudySheetPdf(
        title: 'OS Deadlocks Lecture',
        topic: 'Operating Systems',
        questions: sampleQuestions,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF magic bytes start with '%PDF'
      final header = ascii.decode(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('TC-P6-3: Generates valid printable PDF cheat sheet and high-yield summary', () async {
      const summary = MultiLevelSummary(
        documentTitle: 'Operating Systems Overview',
        topic: 'Operating Systems',
        tldr: 'Operating systems manage concurrency, deadlock prevention, and scheduling.',
        keyPoints: [
          'Deadlock requires 4 simultaneous conditions.',
          'Prevention denies at least one condition.',
          'Avoidance uses Banker algorithm.',
          'Detection runs graph cycles check.',
          'Recovery preempts or aborts.',
        ],
        sections: [
          SectionSummary(
            title: 'Deadlocks',
            subtopic: 'Conditions',
            content: 'Four conditions must hold simultaneously for deadlock to occur.',
            bulletPoints: ['Mutual exclusion', 'Hold and wait'],
            sourcePage: 3,
          ),
        ],
        cheatSheet: ExamCheatSheet(
          definitions: [
            DefinitionItem(term: 'Deadlock', definition: 'Permanent blocking of a set of processes.'),
            DefinitionItem(term: 'Resource Graph', definition: 'Directed graph modeling allocation.'),
          ],
          formulasOrRules: [
            FormulaItem(name: 'Need Formula', formulaOrRule: 'Need = Max - Allocation'),
          ],
          highYieldTips: [
            'Remember resource ordering breaks circular wait.',
          ],
        ),
        glossary: {
          'Mutual Exclusion': 'Only one process can hold the resource.',
        },
        mindMapMermaid: 'graph TD; OS-->Deadlocks;',
      );

      final pdfBytes = await ExportService.instance.generateCheatSheetPdf(
        title: 'Operating Systems Overview',
        topic: 'Operating Systems',
        summary: summary,
      );

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}

