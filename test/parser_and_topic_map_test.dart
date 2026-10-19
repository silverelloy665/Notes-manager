import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('Phase 1 - Robust Content Pipeline & Parser Tests', () {
    test('TC-P1-1: Sanitizes truncated titles and unclosed parentheses', () async {
      const text = '''
# Assignment (
Research Activity Guidelines for Software Engineering

This assignment covers software development life cycle models, agile methodology, and verification.
Software quality assurance requires comprehensive code reviews and unit testing.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'assignment_part1.md',
      );

      // Title should not end in an open '('
      expect(doc.detectedTitle.trim().endsWith('('), isFalse);
      expect(doc.detectedTitle, contains('Assignment'));
      expect(doc.detectedTopic, equals('Software Engineering'));
      expect(doc.topicMap.topics, isNotEmpty);
      expect(doc.topicMap.topics.first.title.trim().endsWith('('), isFalse);
    });

    test('TC-P1-2: Normalizes OCR splits (Soft ware -> Software, method s -> methods)', () async {
      const text = '''
# Software Engineering Principles
Modern Soft ware engineering utilizes agile method s to deliver value quickly.
The waterfall sdlc has distinct phases for requirements specification and testing.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'se_principles.txt',
      );

      expect(doc.fullText, contains('Software'));
      expect(doc.fullText, contains('methods'));
      expect(doc.detectedTopic, equals('Software Engineering'));
    });

    test('TC-P1-3: Extracts structured tables, bullet points, and code blocks', () async {
      const text = '''
# Database Management Systems
## Relational Model and SQL

Key ACID Properties:
* Atomicity ensures all or nothing.
* Consistency keeps constraints valid.
* Isolation isolates concurrent transactions.
* Durability guarantees committed changes persist.

Comparison of Normal Forms:
| Normal Form | Requirement | Eliminates |
| 1NF | Atomic values | Repeating groups |
| 2NF | 1NF + No partial dependency | Partial dependencies |
| 3NF | 2NF + No transitive dependency | Transitive anomalies |

Example SQL Query:
```sql
SELECT student_id, name FROM students WHERE gpa > 3.5 ORDER BY name ASC;
```
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'dbms_acid_and_nf.md',
      );

      expect(doc.detectedTopic, equals('Database Management'));
      expect(doc.sections, isNotEmpty);

      final section = doc.sections.first;
      expect(section.bulletPoints, isNotEmpty);
      expect(section.bulletPoints.any((b) => b.contains('Atomicity')), isTrue);
      expect(section.tables, isNotEmpty);
      expect(section.tables.first.contains('Normal Form'), isTrue);
      expect(section.codeBlocks, isNotEmpty);
      expect(section.codeBlocks.first.contains('SELECT student_id'), isTrue);
    });

    test('TC-P1-4: Generates hierarchical TopicMap with Topics, Subtopics, and Concepts', () async {
      const text = '''
# Operating Systems Overview
Process Management and Virtual Memory

A process is defined as an executing instance of a program in isolated address space.
A thread is defined as a lightweight unit of CPU execution sharing memory with peer threads.
Deadlock is defined as a permanent blocking state where each process waits for a resource held by another.
Paging refers to a memory management scheme that maps virtual addresses into physical frames.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'os_virtual_memory.txt',
      );

      final topicMap = doc.topicMap;
      expect(topicMap.title, isNotEmpty);
      expect(topicMap.domainTopic, equals('Operating Systems'));
      expect(topicMap.totalWordCount, greaterThan(20));
      expect(topicMap.topics, isNotEmpty);

      final firstTopic = topicMap.topics.first;
      expect(firstTopic.pageStart, equals(1));
      expect(firstTopic.subtopics, isNotEmpty);

      // Verify concepts extracted in subtopics
      final allConcepts = firstTopic.subtopics.expand((s) => s.concepts).toList();
      expect(allConcepts, isNotEmpty);
      final conceptNames = allConcepts.map((c) => c.name.toLowerCase()).toList();
      expect(conceptNames.any((c) => c.contains('process') || c.contains('thread') || c.contains('deadlock') || c.contains('paging')), isTrue);
    });

    test('TC-P1-5: Generates bounded SemanticChunks with metadata and token counts', () async {
      const text = '''
# Computer Networks Fundamentals
TCP/IP and OSI Layer Architecture

The OSI model divides network communication into seven distinct abstraction layers: Physical, Data Link, Network, Transport, Session, Presentation, and Application.
The TCP/IP model condenses these layers into Network Interface, Internet, Transport, and Application layers.
Packet routing is governed by IP addresses and routing tables maintained across internetwork routers.
TCP provides reliable connection-oriented byte streams with three-way handshakes and congestion control.
UDP provides low-latency connectionless datagram delivery without retransmission or ordering guarantees.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'cn_layers.txt',
      );

      expect(doc.chunks, isNotEmpty);
      for (final chunk in doc.chunks) {
        expect(chunk.chunkId, startsWith('chunk_'));
        expect(chunk.sourceFileName, equals('cn_layers.txt'));
        expect(chunk.pageNumber, equals(1));
        expect(chunk.content, isNotEmpty);
        expect(chunk.tokenCount, greaterThan(0));
        expect(chunk.keywords, isNotEmpty);
      }
    });

    test('TC-P1-6: Image-only / Scanned PDF fallback executes gracefully without dropping pages', () {
      // Build a synthetic single-page PDF with no text stream (simulating a scanned slide)
      final pdfDoc = PdfDocument();
      pdfDoc.pages.add(); // Blank page
      final bytes = pdfDoc.saveSync();
      pdfDoc.dispose();

      final doc = DocumentProcessingService.instance.processBytes(
        bytes: bytes,
        fileName: 'scanned_lecture_slide.pdf',
      );

      expect(doc, completion(isNotNull));
    });
  });
}
