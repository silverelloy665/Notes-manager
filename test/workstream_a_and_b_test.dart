import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/services/smart_summarization_service.dart';
import 'package:studymate_classroom/services/explain_simply_service.dart';

void main() {
  group('Workstream A - Smarter Summarization Test Suite', () {
    final sampleTopicMap = TopicMap(
      id: 'tm_os_1',
      documentId: 'doc_os_1',
      fileName: 'os.pdf',
      title: 'Operating Systems Principles',
      domainTopic: 'Computer Science',
      pageCount: 10,
      totalWordCount: 500,
      createdAt: DateTime.now(),
      topics: [
        TopicNode(
          id: 't1',
          title: 'Deadlock Detection',
          pageStart: 2,
          pageEnd: 4,
          wordCount: 250,
          contentSnippet: 'Deadlock detection algorithms inspect resource graphs for cycles. Mutual exclusion and hold and wait conditions enable permanent blocking.',
          subtopics: [
            SubtopicNode(
              id: 's1',
              title: 'Resource Allocation Graph',
              pageNumber: 3,
              summary: 'A directed graph modeling process requests and assignments. A cycle in a single-resource graph indicates deadlock.',
              concepts: [
                ConceptNode(name: 'Circular Wait', description: 'A closed loop of processes waiting for held resources.', pageNumber: 3),
              ],
            ),
          ],
        ),
        TopicNode(
          id: 't2',
          title: 'Memory Management',
          pageStart: 5,
          pageEnd: 8,
          wordCount: 250,
          contentSnippet: 'Paging divides memory into fixed-sized frames. Page tables translate logical addresses into physical addresses.',
          subtopics: [
            SubtopicNode(
              id: 's2',
              title: 'Virtual Memory',
              pageNumber: 6,
              summary: 'Virtual memory provides an illusion of vast contiguous memory using demand paging and swap space.',
              concepts: [
                ConceptNode(name: 'Page Fault', description: 'Trap raised when accessing unmapped page.', pageNumber: 6),
              ],
            ),
          ],
        ),
      ],
      chunks: [
        SemanticChunk(
          chunkId: 'c1',
          sourceFileName: 'os.pdf',
          pageNumber: 2,
          topic: 'Deadlock Detection',
          subtopic: 'Resource Allocation Graph',
          content: 'Deadlock detection algorithms inspect resource graphs for cycles. Mutual exclusion is defined as single-thread access.',
          tokenCount: 45,
          keywords: ['deadlock', 'resource', 'graph'],
        ),
      ],
    );

    test('TC-WA-1: Generates complete 7-format bottom-up Map-Reduce summary with citations', () async {
      final summary = await SmartSummarizationService.instance.generateSummary(
        title: 'Operating Systems Lecture',
        topic: 'Operating Systems',
        text: 'Operating systems manage concurrency and memory. Deadlocks occur when resources are held circularly. Paging maps virtual memory to physical frames.',
        topicMap: sampleTopicMap,
        tone: 'academic',
        length: 'detailed',
        language: 'en',
      );

      // (a) One-line TL;DR
      expect(summary.tldr, isNotEmpty);
      expect(summary.tldr.split('.').length, lessThanOrEqualTo(3));

      // (b) 5-8 Key Points with page citations
      expect(summary.keyPoints.length, inInclusiveRange(5, 8));
      expect(summary.keyPoints.any((kp) => kp.contains('[p.')), isTrue);

      // (c) Detailed section breakdown mirroring topics
      expect(summary.sections.length, greaterThanOrEqualTo(2));
      expect(summary.sections.any((s) => s.title.contains('Deadlock Detection')), isTrue);
      expect(summary.sections.any((s) => s.title.contains('Memory Management')), isTrue);

      // (d) Exam Cheat Sheet
      expect(summary.cheatSheet.highYieldTips, isNotEmpty);
      expect(summary.cheatSheet.mustRemember, isNotEmpty);
      expect(summary.cheatSheet.commonMistakes, isNotEmpty);

      // (e) Glossary
      expect(summary.glossary, isNotEmpty);

      // (f) Q&A Summary (5 teacher questions)
      expect(summary.qaSummary.length, equals(5));
      expect(summary.qaSummary.first.question, isNotEmpty);
      expect(summary.qaSummary.first.expectedKeyPoints, isNotEmpty);

      // (g) Mind Map
      expect(summary.mindMapMermaid, contains('graph TD'));

      // Validation Pass
      expect(summary.isVerified, isTrue);
      expect(summary.validationNotes, isNotEmpty);
    });

    test('TC-WA-2: Caches summary results by content hash for instant retrieval', () async {
      final first = await SmartSummarizationService.instance.generateSummary(
        title: 'OS Lecture',
        topic: 'Operating Systems',
        text: 'Paging maps memory into physical frames.',
        topicMap: sampleTopicMap,
      );

      final second = await SmartSummarizationService.instance.generateSummary(
        title: 'OS Lecture',
        topic: 'Operating Systems',
        text: 'Paging maps memory into physical frames.',
        topicMap: sampleTopicMap,
      );

      expect(identical(first, second), isTrue);
      expect(first.contentHash, isNotEmpty);
    });

    test('TC-WA-3: One-click adjustments (makeShorter, addMoreDetail) correctly rescale length', () async {
      final initial = await SmartSummarizationService.instance.generateSummary(
        title: 'OS Lecture',
        topic: 'Operating Systems',
        text: 'Concurrency control ensures serialized schedules across parallel threads.',
        topicMap: sampleTopicMap,
        length: 'detailed',
      );

      final shorter = SmartSummarizationService.instance.makeShorter(initial);
      expect(shorter.length, equals('concise'));
      expect(shorter.keyPoints.length, lessThanOrEqualTo(3));
      expect(shorter.qaSummary.length, lessThanOrEqualTo(3));

      final detailed = SmartSummarizationService.instance.addMoreDetail(initial);
      expect(detailed.length, equals('comprehensive'));
    });
  });

  group('Workstream B - Explain This Simply Test Suite', () {
    const sampleContext = '''
Deadlock prevention works by eliminating one of the four Coffman conditions:
1. Mutual exclusion: Cannot be easily denied for non-shareable resources like printers.
2. Hold and wait: Processes must request all resources before execution begins.
3. No preemption: If a process cannot obtain another resource, its held resources are released.
4. Circular wait: Imposing a strict linear ordering of all resource types prevents cycles.
''';

    test('TC-WB-1: Synthesizes complete 7-part pedagogical explanation structure', () async {
      final explanation = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Deadlock Prevention',
        subtopic: 'Coffman Conditions',
        sourceContext: sampleContext,
        sourcePage: 4,
        targetAudience: 'beginner',
        language: 'en',
      );

      // 1. Plain Idea
      expect(explanation.plainIdea, isNotEmpty);
      expect(explanation.plainIdea, contains('Deadlock Prevention'));

      // 2. Real-life school analogy
      expect(explanation.analogy, isNotEmpty);
      expect(explanation.analogy.length, greaterThan(30));

      // 3. Step-by-step breakdown
      expect(explanation.stepByStep.length, greaterThanOrEqualTo(3));

      // 4. Tiny worked example
      expect(explanation.workedExample, isNotEmpty);

      // 5. Common confusion
      expect(explanation.commonConfusions, isNotEmpty);

      // 6. Memory mnemonic
      expect(explanation.mnemonic, isNotEmpty);

      // 7. 2-question mini check (1 MCQ + 1 short)
      expect(explanation.miniCheckMcq.question, isNotEmpty);
      expect(explanation.miniCheckMcq.options, isNotNull);
      expect(explanation.miniCheckMcq.correctIndex, isNotNull);
      expect(explanation.miniCheckShort.question, isNotEmpty);
      expect(explanation.miniCheckShort.answer, isNotEmpty);

      expect(explanation.sourcePage, equals(4));
    });

    test('TC-WB-2: Level selector rescales pedagogical complexity (Like I\'m 10 vs Exam-Ready)', () async {
      final kid = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Deadlock Prevention',
        sourceContext: sampleContext,
        targetAudience: 'like_im_10',
      );

      expect(kid.targetAudience, equals('like_im_10'));
      expect(kid.plainIdea, contains('smart helper'));

      final exam = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Deadlock Prevention',
        sourceContext: sampleContext,
        targetAudience: 'exam_ready',
      );

      expect(exam.targetAudience, equals('exam_ready'));
    });

    test('TC-WB-3: Multi-language support (Hinglish/Hindi) generates accessible vocabulary', () async {
      final hindi = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Deadlock Prevention',
        sourceContext: sampleContext,
        language: 'hi',
      );

      expect(hindi.language, equals('hi'));
      expect(hindi.plainIdea, contains('shabdon mein'));
      expect(hindi.mnemonic, contains('mantra'));
    });

    test('TC-WB-4: Inline tailored mistake feedback references wrong option chosen', () async {
      final tailored = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Deadlock Prevention',
        sourceContext: sampleContext,
        wrongOptionChosen: 'Allowing all processes to hold resources indefinitely',
      );

      expect(tailored.tailoredMistakeNote, isNotNull);
      expect(tailored.tailoredMistakeNote, contains('Allowing all processes to hold resources indefinitely'));
    });

    test('TC-WB-5: Explains insufficient content gracefully without hallucinating', () async {
      final brief = await ExplainSimplyService.instance.generateExplanation(
        topic: 'Quantum Computing',
        sourceContext: 'Intro to quantum.',
      );

      expect(brief.plainIdea, contains('briefly without sufficient text'));
      expect(brief.workedExample, contains('No worked example is available'));
    });
  });
}
