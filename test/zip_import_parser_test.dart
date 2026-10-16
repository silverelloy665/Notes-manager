import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/services/zip_import_parser.dart';
import 'package:studymate_classroom/utils/app_exception.dart';

Uint8List createZipArchive(Map<String, dynamic> files) {
  final archive = Archive();
  files.forEach((path, content) {
    List<int> bytes;
    if (content is String) {
      bytes = utf8.encode(content);
    } else if (content is List<int>) {
      bytes = content;
    } else {
      bytes = utf8.encode(content.toString());
    }
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });
  final encoder = ZipEncoder();
  final encoded = encoder.encode(archive);
  return Uint8List.fromList(encoded!);
}

void main() {
  group('ZipImportParser Positive Test Suite', () {
    test('TC-Z-P1: Standard layout creates Subject, Unit, Notes and Practicals correctly', () {
      final zipBytes = createZipArchive({
        'Operating Systems/Unit 1 - Basics/notes/intro.txt': 'Introduction to OS concepts',
        'Operating Systems/Unit 1 - Basics/practicals/fork_demo.c': '#include <stdio.h>\nint main() { return 0; }',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.errors, isEmpty);
      expect(result.subjects.length, equals(1));
      final subject = result.subjects.first;
      expect(subject.name, equals('Operating Systems'));
      expect(subject.units.length, equals(1));

      final unit = subject.units.first;
      expect(unit.number, equals(1));
      expect(unit.title, equals('Basics'));
      expect(unit.notes.length, equals(1));
      expect(unit.notes.first.name, equals('intro.txt'));
      expect(unit.practicals.length, equals(1));
      expect(unit.practicals.first.name, equals('fork_demo.c'));
    });

    test('TC-Z-P2: Unit prefixes with hyphens and dots parse numbers and titles correctly', () {
      final zipBytes = createZipArchive({
        'DBMS/Unit 2 - SQL Fundamentals/notes/queries.sql': 'SELECT * FROM users;',
        'DBMS/Unit 3. Indexing & Hashing/notes/btree.txt': 'B-Tree indexing details',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.errors, isEmpty);
      final units = result.subjects.first.units;
      expect(units.length, equals(2));
      expect(units[0].number, equals(2));
      expect(units[0].title, equals('SQL Fundamentals'));
      expect(units[1].number, equals(3));
      expect(units[1].title, equals('Indexing & Hashing'));
    });

    test('TC-Z-P3: Unit without prefix receives sequential inferred number', () {
      final zipBytes = createZipArchive({
        'Networks/Routing Protocols/notes/rip.txt': 'Routing Information Protocol',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.errors, isEmpty);
      final unit = result.subjects.first.units.first;
      expect(unit.number, equals(1));
      expect(unit.title, equals('Routing Protocols'));
    });

    test('TC-Z-P4: Laboratory folder aliases (lab, code, experiments) are identified as practicals', () {
      final zipBytes = createZipArchive({
        'Physics/Unit 1 - Mechanics/lab/pendulum.txt': 'Simple pendulum experiment',
        'Physics/Unit 1 - Mechanics/code/sim.py': 'print("gravity simulation")',
        'Physics/Unit 1 - Mechanics/notes/formulae.pdf': 'Kinematics formulas',
      });

      final result = ZipImportParser.parse(zipBytes);

      final unit = result.subjects.first.units.first;
      expect(unit.practicals.length, equals(2));
      expect(unit.notes.length, equals(1));
      expect(unit.practicals.any((p) => p.name == 'pendulum.txt'), isTrue);
      expect(unit.practicals.any((p) => p.name == 'sim.py'), isTrue);
      expect(unit.notes.any((n) => n.name == 'formulae.pdf'), isTrue);
    });

    test('TC-Z-P5: Extraction of questions.json extracts structured questions and answers', () {
      final questionsJson = jsonEncode([
        {
          'question': 'What is a process control block (PCB)?',
          'answer': 'A PCB is a data structure used by the OS to manage process information.'
        },
        {
          'question': 'Explain context switching.',
          'answer': 'Context switching is the mechanism of saving and restoring CPU state.'
        }
      ]);

      final zipBytes = createZipArchive({
        'Operating Systems/Unit 1 - Processes/questions.json': questionsJson,
        'Operating Systems/Unit 1 - Processes/notes/pcb.txt': 'PCB details',
      });

      final result = ZipImportParser.parse(zipBytes);

      final unit = result.subjects.first.units.first;
      expect(unit.questions.length, equals(2));
      expect(unit.questions.first.question, contains('process control block'));
      expect(unit.questions.first.answer, contains('PCB is a data structure'));
    });

    test('TC-Z-P6: Root level files are collected into an inferred Unit 1 - General', () {
      final zipBytes = createZipArchive({
        'Chemistry/syllabus.pdf': 'Syllabus content',
        'Chemistry/reference.txt': 'Recommended books',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.subjects.length, equals(1));
      final unit = result.subjects.first.units.first;
      expect(unit.title, equals('General'));
      expect(unit.notes.length, equals(2));
    });
  });

  group('ZipImportParser Negative & Security Test Suite', () {
    test('TC-Z-N1: Corrupted or non-ZIP bytes throws AppException', () {
      final corruptedBytes = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
      expect(
        () => ZipImportParser.parse(corruptedBytes),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Corrupted or invalid'))),
      );
    });

    test('TC-Z-N2: Empty ZIP archive throws AppException', () {
      expect(
        () => ZipImportParser.parse(Uint8List(0)),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('empty'))),
      );
    });

    test('TC-Z-N3: Zip-slip directory traversal paths (../) are rejected and skipped', () {
      final zipBytes = createZipArchive({
        'Operating Systems/../../etc/passwd': 'malicious content',
        'Operating Systems/Unit 1 - Intro/notes/ok.txt': 'Safe content',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.skippedFiles.any((f) => f.contains('passwd')), isTrue);
      // Valid file is still parsed
      expect(result.subjects.length, equals(1));
      expect(result.subjects.first.units.first.notes.length, equals(1));
    });

    test('TC-Z-N4: Executables (.exe, .bat, .apk, .sh) are skipped with notice', () {
      final zipBytes = createZipArchive({
        'Operating Systems/Unit 1 - Tools/practicals/malware.exe': 'binary executable',
        'Operating Systems/Unit 1 - Tools/practicals/run.bat': '@echo off',
        'Operating Systems/Unit 1 - Tools/notes/guide.txt': 'Safe text guide',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.skippedFiles.length, equals(2));
      expect(result.skippedFiles.any((f) => f.contains('malware.exe')), isTrue);
      expect(result.skippedFiles.any((f) => f.contains('run.bat')), isTrue);
      final unit = result.subjects.first.units.first;
      expect(unit.practicals, isEmpty);
      expect(unit.notes.length, equals(1));
    });

    test('TC-Z-N5: Malformed JSON in questions.json is skipped without crashing parse', () {
      final zipBytes = createZipArchive({
        'DBMS/Unit 1 - Overview/questions.json': '{ "not_a_valid_json_array": true, broken ',
        'DBMS/Unit 1 - Overview/notes/overview.txt': 'Overview notes',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.errors.length, equals(1));
      expect(result.errors.first, contains('Failed to parse questions.json'));
      final unit = result.subjects.first.units.first;
      expect(unit.questions, isEmpty);
      expect(unit.notes.length, equals(1));
    });

    test('TC-Z-N6: Top-level unit folder without subject sets requiresSubjectNamePrompt', () {
      final zipBytes = createZipArchive({
        'Unit 1 - CPU Scheduling/notes/fcfs.txt': 'First come first served notes',
      });

      final result = ZipImportParser.parse(zipBytes);

      expect(result.requiresSubjectNamePrompt, isTrue);
    });
  });
}
