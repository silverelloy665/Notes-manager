import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';

void main() {
  group('Phase 4 - Smart Summarization & Map-Reduce Test Suite', () {
    late TopicMap sampleTopicMap;
    const documentText = '''
Process Management is the core responsibility of the Operating System.
A Process Control Block (PCB) is defined as a data structure maintaining the execution state, program counter, and CPU registers for an active thread.
Context switching is the process of saving the state of the currently running process and restoring the state of the next ready process.
The CPU scheduler utilizes algorithms such as Round Robin, Shortest Job First, and FIFO.
Deadlock occurs when four Coffman conditions hold simultaneously: Mutual Exclusion, Hold and Wait, No Preemption, and Circular Wait.
Resource allocation graphs represent processes and resources as directed bipartite graphs.
''';

    setUp(() {
      sampleTopicMap = TopicMap(
        id: 'tm-101',
        documentId: 'doc-101',
        fileName: 'os.pdf',
        title: 'Operating Systems: Architecture & Core Mechanics',
        domainTopic: 'Operating Systems',
        pageCount: 10,
        totalWordCount: 770,
        createdAt: DateTime(2026, 1, 1),
        topics: const [
          TopicNode(
            id: 't1',
            title: 'Process Management',
            pageStart: 2,
            pageEnd: 5,
            contentSnippet: 'Explores process lifecycle, context switching, and state transitions.',
            wordCount: 350,
            subtopics: [
              SubtopicNode(
                id: 'st1',
                title: 'Process Control Block (PCB)',
                pageNumber: 3,
                summary: 'A Process Control Block (PCB) is defined as a data structure maintaining execution state and registers.',
                concepts: [
                  ConceptNode(name: 'PCB', description: 'Process control block data structure', pageNumber: 3),
                ],
              ),
              SubtopicNode(
                id: 'st2',
                title: 'Context Switching Mechanics',
                pageNumber: 4,
                summary: 'Context switching is the process of saving the active process state and restoring the scheduled process.',
                concepts: [],
              ),
            ],
          ),
          TopicNode(
            id: 't2',
            title: 'Deadlock Prevention & Detection',
            pageStart: 6,
            pageEnd: 9,
            contentSnippet: 'Investigates Coffman conditions, resource allocation graphs, and prevention algorithms.',
            wordCount: 420,
            subtopics: [
              SubtopicNode(
                id: 'st3',
                title: 'Coffman Conditions',
                pageNumber: 7,
                summary: 'Deadlock requires mutual exclusion, hold and wait, no preemption, and circular wait.',
                concepts: [],
              ),
            ],
          ),
        ],
        chunks: [
          SemanticChunk(
            chunkId: 'c1',
            sourceFileName: 'os.pdf',
            pageNumber: 3,
            topic: 'Process Management',
            subtopic: 'Process Control Block (PCB)',
            content: 'A Process Control Block (PCB) is defined as a data structure maintaining the execution state, program counter, and CPU registers for an active thread.',
            keywords: ['PCB', 'registers', 'execution'],
            tokenCount: 25,
          ),
          SemanticChunk(
            chunkId: 'c2',
            sourceFileName: 'os.pdf',
            pageNumber: 7,
            topic: 'Deadlock Prevention & Detection',
            subtopic: 'Coffman Conditions',
            content: 'Deadlock occurs when four Coffman conditions hold simultaneously: Mutual Exclusion, Hold and Wait, No Preemption, and Circular Wait.',
            keywords: ['Deadlock', 'Coffman'],
            tokenCount: 22,
          ),
        ],
      );
    });

    test('Map-Reduce produces complete multi-level summary covering all topics without loss', () async {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
        tone: 'academic',
        length: 'detailed',
      );

      // (a) One-line TL;DR
      expect(summary.tldr, isNotEmpty);
      expect(summary.tldr.contains('Operating Systems'), isTrue);

      // (b) 5-8 bullet key points
      expect(summary.keyPoints.length, inInclusiveRange(5, 8));
      for (final kp in summary.keyPoints) {
        expect(kp, isNotEmpty);
      }

      // (c) Detailed section-by-section breakdown: Every single topic and subtopic is covered
      final sectionTitles = summary.sections.map((s) => s.title).toList();
      expect(sectionTitles, contains('Process Management'));
      expect(sectionTitles.any((t) => t.contains('Process Control Block')), isTrue);
      expect(sectionTitles.any((t) => t.contains('Context Switching')), isTrue);
      expect(sectionTitles, contains('Deadlock Prevention & Detection'));
      expect(sectionTitles.any((t) => t.contains('Coffman Conditions')), isTrue);

      // Verify each section preserves its source page
      final pcbSection = summary.sections.firstWhere((s) => s.title.contains('Process Control Block'));
      expect(pcbSection.sourcePage, 3);
    });

    test('Exam cheat sheet extracts definitions, algorithmic rules, and exam tips', () async {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
      );

      final cheatSheet = summary.cheatSheet;
      expect(cheatSheet.definitions, isNotEmpty);
      expect(cheatSheet.definitions.any((d) => d.term.toLowerCase().contains('pcb') || d.term.toLowerCase().contains('process control block')), isTrue);
      expect(cheatSheet.highYieldTips, isNotEmpty);
    });

    test('Alphabetical Glossary is constructed from grounded terms', () async {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
      );

      expect(summary.glossary, isNotEmpty);
      expect(summary.glossary.keys.any((k) => k.toLowerCase().contains('pcb') || k.toLowerCase().contains('process control block')), isTrue);
    });

    test('Mermaid mind map syntax is correctly formatted', () async {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
      );

      expect(summary.mindMapMermaid, startsWith('graph TD'));
      expect(summary.mindMapMermaid.contains('Operating_Systems') || summary.mindMapMermaid.contains('Root['), isTrue);
      expect(summary.mindMapMermaid, contains('Process Management'));
    });

    test('Show source references toggle correctly formats markdown with and without [p. X]', () async {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
      );

      final withSources = summary.toMarkdown(includeSources: true);
      final withoutSources = summary.toMarkdown(includeSources: false);

      expect(withSources, contains('[p. 3]'));
      expect(withoutSources, isNot(contains('[p. 3]')));
    });

    test('Customization options: tone and length adjust synthesis appropriately', () async {
      final academicSummary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
        tone: 'academic',
        length: 'detailed',
      );

      final simpleConciseSummary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: sampleTopicMap.title,
        topic: 'Operating Systems',
        text: documentText,
        topicMap: sampleTopicMap,
        tone: 'simple',
        length: 'concise',
      );

      expect(academicSummary.tldr, isNot(equals(simpleConciseSummary.tldr)));
      expect(simpleConciseSummary.keyPoints.length, lessThanOrEqualTo(academicSummary.keyPoints.length));
      expect(academicSummary.keyPoints.length, inInclusiveRange(5, 8));
    });
  });
}
