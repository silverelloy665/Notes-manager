import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';

void main() {
  group('DocumentProcessingService Tests', () {
    test('Detects Operating Systems topic and generates structured sections', () async {
      const text = '''
# Operating Systems Lecture 3
Process and Thread Management

A process is defined as an executing instance of an application program with isolated memory space.
A thread is defined as a basic unit of CPU utilization that shares memory within a parent process.

Deadlock is a condition where a set of processes are blocked because each process is holding a resource and waiting for another resource.
Paging refers to a memory management scheme that eliminates the need for contiguous allocation of physical memory.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'os_lecture_notes.txt',
      );

      expect(doc.detectedTopic, equals('Operating Systems'));
      expect(doc.detectedTitle, contains('Operating Systems Lecture 3'));
      expect(doc.fullText, contains('Process and Thread Management'));
      expect(doc.sections, isNotEmpty);
    });

    test('Detects Database Management topic and extracts definitions', () async {
      const text = '''
# Relational Database Design
Normalization and ACID Properties

DBMS is defined as a computerized system that enables users to create and maintain databases.
Normalization refers to the process of organizing data in a database to reduce redundancy and improve data integrity.
''';

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: text.codeUnits,
        fileName: 'dbms_normalization.md',
      );

      expect(doc.detectedTopic, equals('Database Management'));
      expect(doc.detectedTitle, contains('Relational Database Design'));
    });
  });

  group('NotesAiService Tests', () {
    test('Generates comprehensive structured summary with overview, concepts, and tips', () async {
      const content = '''
A semaphore is defined as a synchronization tool that provides a sophisticated way to control access to shared variables.
A mutex refers to a locking mechanism used to synchronize access to a resource with ownership semantics.
Paging allows the physical address space of a process to be noncontiguous.
It is important to remember that binary semaphores can be signaled by any thread.
''';

      final summary = await NotesAiService.instance.summarize(
        text: content,
        title: 'Concurrency & Paging',
        topic: 'Operating Systems',
      );

      expect(summary, contains('## ⚡ One-Line TL;DR'));
      expect(summary, contains('## 🔑 5 High-Yield Key Points'));
      expect(summary, contains('## 📖 Section-by-Section Deep Dive'));
      expect(summary, contains('## 📝 Exam Cheat Sheet'));
      expect(summary, contains('semaphore'));
    });

    test('Generates practice questions with answers directly from note topics', () async {
      const content = '''
Virtual memory is defined as a memory management capability that provides an idealized abstraction of storage resources.
A page fault refers to an exception raised by the memory management unit when a process accesses a memory page not in RAM.
''';

      final questions = await NotesAiService.instance.generatePracticeQuestions(
        text: content,
        title: 'Virtual Memory & Page Faults',
        topic: 'Operating Systems',
        count: 2,
      );

      expect(questions.length, greaterThanOrEqualTo(2));
      for (final q in questions) {
        expect(q.topic, equals('Operating Systems'));
        expect(q.question, isNotEmpty);
        expect(q.answer, isNotEmpty);
      }
    });
  });
}

