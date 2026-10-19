import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/coverage_report_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';

void main() {
  group('Phase 2 — CoverageReport and TopicCoverageStats Model Tests', () {
    test('Calculates page coverage percentage and serializes correctly', () {
      final stats = {
        'Virtual Memory': const TopicCoverageStats(
          topic: 'Virtual Memory',
          totalQuestions: 15,
          mcqCount: 10,
          conceptualCount: 5,
          easyCount: 4,
          mediumCount: 6,
          hardCount: 5,
          coveredSubtopics: 3,
          totalSubtopics: 3,
          isFullyCovered: true,
        ),
      };

      final report = CoverageReport(
        documentId: 'doc_123',
        fileName: 'os_virtual_memory.pdf',
        totalQuestions: 15,
        mcqCount: 10,
        conceptualCount: 5,
        totalPages: 10,
        coveredPages: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        pageCoveragePercentage: 100.0,
        topicStats: stats,
        is100PercentCovered: true,
        generatedAt: DateTime(2026, 1, 1),
      );

      expect(report.pageCoveragePercentage, equals(100.0));
      expect(report.is100PercentCovered, isTrue);

      final map = report.toMap();
      final roundtrip = CoverageReport.fromMap(map);
      expect(roundtrip.documentId, equals('doc_123'));
      expect(roundtrip.pageCoveragePercentage, equals(100.0));
      expect(roundtrip.topicStats['Virtual Memory']?.mcqCount, equals(10));
      expect(roundtrip.topicStats['Virtual Memory']?.conceptualCount, equals(5));
    });
  });

  group('Phase 2 — Deep Question Generation Engine Tests', () {
    test('Generates questions for every topic/subtopic node with 3 Bloom tiers and distractors', () async {
      final topicMap = TopicMap(
        id: 'test_doc_os',
        documentId: 'doc_os_1',
        fileName: 'os_lecture.pdf',
        title: 'Operating Systems Overview',
        domainTopic: 'Operating Systems',
        pageCount: 4,
        totalWordCount: 800,
        createdAt: DateTime(2026, 1, 1),
        topics: [
          TopicNode(
            id: 't1',
            title: 'Process Management',
            pageStart: 1,
            pageEnd: 2,
            contentSnippet: 'Process control blocks contain CPU registers. Transitions between Ready, Running, and Blocked.',
            wordCount: 400,
            subtopics: [
              SubtopicNode(
                id: 'st1',
                title: 'Context Switching & PCB',
                pageNumber: 1,
                summary: 'PCB stores registers and state.',
                concepts: [
                  ConceptNode(name: 'PCB', description: 'Process Control Block storing state', pageNumber: 1),
                ],
              ),
              SubtopicNode(
                id: 'st2',
                title: 'Process State Transitions',
                pageNumber: 2,
                summary: 'States Ready, Running, Blocked.',
                concepts: [
                  ConceptNode(name: 'Ready State', description: 'Process waiting for CPU allocation', pageNumber: 2),
                ],
              ),
            ],
          ),
          TopicNode(
            id: 't2',
            title: 'Memory Management',
            pageStart: 3,
            pageEnd: 4,
            contentSnippet: 'Paging eliminates external fragmentation. LRU evicts unreferenced page.',
            wordCount: 400,
            subtopics: [
              SubtopicNode(
                id: 'st3',
                title: 'Paging & TLB',
                pageNumber: 3,
                summary: 'Paging divides memory into frames.',
                concepts: [
                  ConceptNode(name: 'TLB', description: 'Translation Lookaside Buffer cache', pageNumber: 3),
                ],
              ),
              SubtopicNode(
                id: 'st4',
                title: 'Page Replacement Algorithms',
                pageNumber: 4,
                summary: 'Algorithms decide frame eviction.',
                concepts: [
                  ConceptNode(name: 'LRU', description: 'Least Recently Used page eviction', pageNumber: 4),
                ],
              ),
            ],
          ),
        ],
        chunks: [
          SemanticChunk(chunkId: 'c1', sourceFileName: 'os_lecture.pdf', pageNumber: 1, topic: 'Process Management', subtopic: 'Context Switching & PCB', content: 'Process control blocks contain CPU registers.', keywords: ['pcb', 'context'], tokenCount: 10),
          SemanticChunk(chunkId: 'c2', sourceFileName: 'os_lecture.pdf', pageNumber: 2, topic: 'Process Management', subtopic: 'Process State Transitions', content: 'Transitions between Ready, Running, and Blocked.', keywords: ['transitions', 'states'], tokenCount: 10),
          SemanticChunk(chunkId: 'c3', sourceFileName: 'os_lecture.pdf', pageNumber: 3, topic: 'Memory Management', subtopic: 'Paging & TLB', content: 'Paging eliminates external fragmentation.', keywords: ['paging', 'tlb'], tokenCount: 10),
          SemanticChunk(chunkId: 'c4', sourceFileName: 'os_lecture.pdf', pageNumber: 4, topic: 'Memory Management', subtopic: 'Page Replacement Algorithms', content: 'LRU evicts the page unreferenced for the longest time.', keywords: ['lru', 'replacement'], tokenCount: 10),
        ],
      );

      final processedDoc = ProcessedDocument(
        fileName: 'os_lecture.pdf',
        fileType: 'pdf',
        detectedTitle: 'Operating Systems Overview',
        fullText: 'Process Management and Memory Management in Operating Systems.',
        sections: [
          DocumentSection(title: 'Process Management', content: 'PCB and context switching.', pageNumber: 1),
          DocumentSection(title: 'Process States', content: 'Ready Running Blocked.', pageNumber: 2),
          DocumentSection(title: 'Paging & TLB', content: 'Paging eliminates fragmentation.', pageNumber: 3),
          DocumentSection(title: 'Page Replacement', content: 'LRU replacement algorithm.', pageNumber: 4),
        ],
        detectedTopic: 'Operating Systems',
        topicMap: topicMap,
      );

      final stagesRecorded = <DocumentProcessingStage>[];
      final result = await NotesAiService.instance.generateDeepCoverageQuestions(
        doc: processedDoc,
        onProgress: (stage, status, progress) {
          stagesRecorded.add(stage);
        },
      );

      expect(result.questions.isNotEmpty, isTrue);
      expect(result.report.is100PercentCovered, isTrue);
      expect(result.report.pageCoveragePercentage, equals(100.0));
      expect(stagesRecorded, contains(DocumentProcessingStage.generatingQuestions));
      expect(stagesRecorded, contains(DocumentProcessingStage.validating));

      // 1. Verify coverage of all topics
      final generatedTopics = result.questions.map((q) => q.topic).toSet();
      expect(generatedTopics, contains('Operating Systems'));

      // 2. Verify MCQs and Conceptual counts
      final mcqs = result.questions.where((q) => q.isMcq).toList();
      final conceptuals = result.questions.where((q) => !q.isMcq).toList();
      expect(mcqs.length, greaterThanOrEqualTo(4));
      expect(conceptuals.length, greaterThanOrEqualTo(4));

      // 3. Verify MCQs have 4 distinct options, valid correct option index, and distractor reasoning
      for (final mcq in mcqs) {
        expect(mcq.options, isNotNull);
        expect(mcq.options!.length, equals(4));
        final uniqueOptions = mcq.options!.toSet();
        expect(uniqueOptions.length, equals(4));
        expect(mcq.correctOptionIndex, inInclusiveRange(0, 3));
        expect(mcq.distractorReasoning, isNotNull);
        expect(mcq.distractorReasoning!.length, equals(4));
        // No lazy options
        expect(mcq.options!.any((o) => o.toLowerCase().contains('none of the above')), isFalse);
        expect(mcq.options!.any((o) => o.toLowerCase().contains('all of the above')), isFalse);
      }

      // 4. Verify Depth Tiers across Easy, Medium, Hard
      final difficulties = result.questions.map((q) => q.difficulty).toSet();
      expect(difficulties, contains('Easy'));
      expect(difficulties, contains('Medium'));
      expect(difficulties, contains('Hard'));

      // 5. Verify Bloom Taxonomy levels
      final bloomLevels = result.questions.map((q) => q.bloomLevel).toSet();
      expect(bloomLevels.any((b) => b == 'Remember' || b == 'Understand'), isTrue);
      expect(bloomLevels.any((b) => b == 'Apply'), isTrue);
      expect(bloomLevels.any((b) => b == 'Analyze' || b == 'Evaluate'), isTrue);
    });

    test('Full document processing pipeline generates grounded questions and 100% coverage', () async {
      const sampleText = '''
=== Slide 1 ===
Operating Systems: Deadlock Fundamentals

=== Slide 2 ===
Deadlock Characterization and Conditions
A deadlock occurs when processes hold resources while waiting for other resources.
The four Coffman conditions are mutual exclusion, hold and wait, no preemption, and circular wait.

=== Slide 3 ===
Deadlock Handling Strategies
Systems can prevent deadlocks, avoid them dynamically using the Banker's Algorithm, or detect and recover.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: sampleText.codeUnits,
        fileName: 'deadlocks.txt',
      );

      expect(doc.topicMap, isNotNull);
      final result = await NotesAiService.instance.processDocument(doc);

      expect(result.practiceQuestions.isNotEmpty, isTrue);
      expect(result.coverageReport, isNotNull);
      expect(result.coverageReport!.is100PercentCovered, isTrue);
      expect(result.coverageReport!.mcqCount, greaterThanOrEqualTo(2));
      expect(result.coverageReport!.conceptualCount, greaterThanOrEqualTo(2));
    });
  });

  group('Phase 2 — Conceptual Answer AI & Rubric Grading Tests', () {
    const testQuestion = Question(
      id: 'q_deadlock_1',
      topic: 'Operating Systems',
      question: 'Explain the four conditions necessary for a deadlock to occur.',
      answer: 'The four necessary Coffman conditions are: 1. Mutual Exclusion: At least one resource must be held in a non-shareable mode. 2. Hold and Wait: A process holds resources while requesting others. 3. No Preemption: Resources cannot be forcibly taken. 4. Circular Wait: A closed chain of processes exists where each holds a resource requested by the next.',
      keyPointsRubric: [
        'Mutual exclusion condition',
        'Hold and wait condition',
        'No preemption condition',
        'Circular wait condition',
      ],
    );

    test('Grades strong answer with high score and key points hit', () async {
      const strongAnswer = '''
For a deadlock to arise in an operating system, four conditions must simultaneously hold:
1. Mutual exclusion: resources are non-shareable.
2. Hold and wait: processes hold allocated resources while waiting for more.
3. No preemption: resources cannot be preempted until released voluntarily.
4. Circular wait: a closed cycle of processes exists waiting on each other.
''';

      final grade = await NotesAiService.instance.gradeConceptualAnswer(
        question: testQuestion,
        studentAnswer: strongAnswer,
      );

      expect(grade.score, greaterThanOrEqualTo(70));
      expect(grade.keyPointsHit.isNotEmpty, isTrue);
      expect(grade.keyPointsMissed.length, lessThanOrEqualTo(2));
      expect(grade.feedback.isNotEmpty, isTrue);
    });

    test('Grades empty or trivial answer with score 0 and helpful advice', () async {
      final grade = await NotesAiService.instance.gradeConceptualAnswer(
        question: testQuestion,
        studentAnswer: 'idk',
      );

      expect(grade.score, equals(0));
      expect(grade.gradeLetter, equals('Needs Review'));
      expect(grade.feedback, contains('too short'));
      expect(grade.keyPointsMissed.length, equals(4));
    });

    test('Identifies missed key points on incomplete answer', () async {
      const partialAnswer = 'Mutual exclusion is when only one process can use a resource at a time.';

      final grade = await NotesAiService.instance.gradeConceptualAnswer(
        question: testQuestion,
        studentAnswer: partialAnswer,
      );

      expect(grade.score, lessThan(70));
      expect(grade.keyPointsMissed, contains('Circular wait condition'));
    });
  });
}
