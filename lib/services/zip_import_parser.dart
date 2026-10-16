import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/utils/app_exception.dart';

/// Pure Dart parser for study material ZIP archives.
/// Contains zero Flutter UI or Firebase dependencies so it can execute in isolates or unit tests.
class ZipImportParser {
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const int maxEntryCount = 2000;

  static const List<String> executableExtensions = [
    '.exe', '.apk', '.sh', '.bat', '.cmd', '.bin',
    '.msi', '.vbs', '.ps1', '.jar', '.app', '.com',
  ];

  static const List<String> ignoredFilenames = [
    '.ds_store', 'thumbs.db', 'desktop.ini',
  ];

  /// Parses raw ZIP archive bytes into structured subjects, units, notes, practicals, and questions.
  static ZipParseResult parse(List<int> zipBytes, {String defaultSubjectName = 'General'}) {
    if (zipBytes.isEmpty) {
      throw const AppException('The selected ZIP file is empty.');
    }

    if (zipBytes.length > maxFileSizeBytes) {
      throw const AppException('ZIP archive exceeds the maximum limit of 100 MB.');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } catch (e) {
      throw AppException('Corrupted or invalid ZIP archive: $e');
    }

    if (archive.isEmpty) {
      throw const AppException('The ZIP archive contains no files.');
    }

    if (archive.length > maxEntryCount) {
      throw AppException(
        'ZIP archive exceeds maximum entry limit ($maxEntryCount entries found).',
      );
    }

    final List<String> skippedFiles = [];
    final List<String> errors = [];

    // Map: subjectName -> Map: unitKey -> ParsedUnitAccumulator
    final Map<String, Map<String, _UnitAccumulator>> subjectsMap = {};
    bool hasRootFilesWithoutSubject = false;

    for (final entry in archive) {
      // 1. Skip directory entries
      if (!entry.isFile) continue;

      final rawName = entry.name.replaceAll('\\', '/');

      // 2. Security Check: Zip-Slip defense
      if (_isZipSlip(rawName)) {
        skippedFiles.add('$rawName (Blocked: Zip-slip path traversal attempt)');
        continue;
      }

      // 3. Ignore system/hidden artifacts
      if (_isSystemOrHidden(rawName)) {
        skippedFiles.add(rawName);
        continue;
      }

      // 4. Skip executable binaries
      final ext = p.extension(rawName).toLowerCase();
      if (executableExtensions.contains(ext)) {
        skippedFiles.add('$rawName (Skipped executable)');
        continue;
      }

      // 5. Extract file bytes
      final fileData = entry.content as List<int>;
      final size = fileData.length;

      // Normalize path segments
      final normalizedPath = p.normalize(rawName).replaceAll('\\', '/');
      final segments = normalizedPath.split('/').where((s) => s.isNotEmpty).toList();

      if (segments.isEmpty) continue;

      String subjectName;
      String unitFolder;
      bool isDirectUnderSubject = false;

      final firstFolder = segments[0];
      final isFirstFolderUnit = RegExp(r'^(?:Unit|U|Module)[\s_-]*\d+', caseSensitive: false).hasMatch(firstFolder);

      if (segments.length == 1) {
        // File at the root of the ZIP
        hasRootFilesWithoutSubject = true;
        subjectName = defaultSubjectName;
        unitFolder = 'General';
      } else if (isFirstFolderUnit) {
        // Top-level folder is directly a Unit (e.g. Unit 1 - Introduction/notes/file.pdf)
        hasRootFilesWithoutSubject = true;
        subjectName = defaultSubjectName;
        unitFolder = firstFolder;
      } else if (segments.length == 2) {
        // e.g. Subject/file.pdf OR Subject/Unit1
        subjectName = _sanitizeName(segments[0]);
        unitFolder = 'General';
        isDirectUnderSubject = true;
      } else {
        // segments.length >= 3: e.g. Subject/Unit 1 - Introduction/notes/file.pdf
        subjectName = _sanitizeName(segments[0]);
        unitFolder = segments[1];
      }

      // Check for optional questions.json per unit
      final fileName = segments.last;
      if (fileName.toLowerCase() == 'questions.json') {
        try {
          final jsonString = utf8.decode(fileData, allowMalformed: false);
          final decoded = json.decode(jsonString);
          if (decoded is List) {
            final List<ParsedQuestion> questions = [];
            for (final item in decoded) {
              if (item is Map) {
                final q = item['question']?.toString() ?? '';
                final a = item['answer']?.toString() ?? '';
                if (q.isNotEmpty && a.isNotEmpty) {
                  questions.add(ParsedQuestion(question: q, answer: a));
                }
              }
            }
            final unitAcc = _getOrCreateUnit(subjectsMap, subjectName, unitFolder);
            unitAcc.questions.addAll(questions);
          } else {
            errors.add('questions.json in $unitFolder must contain a JSON array.');
          }
        } catch (e) {
          errors.add('Failed to parse questions.json in $unitFolder: $e');
        }
        continue;
      }

      // Determine Note vs Practical
      final isPractical = _isPracticalFile(segments, isDirectUnderSubject);
      final fileType = ext.startsWith('.') ? ext.substring(1) : ext;

      final parsedFile = ParsedFile(
        name: _sanitizeName(p.basename(rawName)),
        type: isPractical ? 'practical' : 'note',
        fileType: fileType.isEmpty ? 'txt' : fileType,
        relativePath: '$subjectName/$unitFolder/${isPractical ? 'practicals' : 'notes'}/$fileName',
        bytes: fileData,
        sizeBytes: size,
      );

      final unitAcc = _getOrCreateUnit(subjectsMap, subjectName, unitFolder);
      if (isPractical) {
        unitAcc.practicals.add(parsedFile);
      } else {
        unitAcc.notes.add(parsedFile);
      }
    }

    // Convert accumulators to final immutable models
    final List<ParsedSubject> parsedSubjects = [];

    subjectsMap.forEach((subName, unitsMap) {
      final List<ParsedUnit> parsedUnits = [];
      unitsMap.forEach((unitKey, acc) {
        if (acc.notes.isNotEmpty || acc.practicals.isNotEmpty || acc.questions.isNotEmpty) {
          final unitMeta = _parseUnitInfo(unitKey);
          parsedUnits.add(
            ParsedUnit(
              number: unitMeta.number,
              title: unitMeta.title,
              notes: acc.notes,
              practicals: acc.practicals,
              questions: acc.questions,
            ),
          );
        }
      });

      // Sort units by unit number
      parsedUnits.sort((a, b) => a.number.compareTo(b.number));

      if (parsedUnits.isNotEmpty) {
        parsedSubjects.add(
          ParsedSubject(
            name: subName,
            units: parsedUnits,
          ),
        );
      }
    });

    if (parsedSubjects.isEmpty) {
      throw const AppException(
        'No valid notes or practical files found in the archive.',
      );
    }

    return ZipParseResult(
      subjects: parsedSubjects,
      skippedFiles: skippedFiles,
      errors: errors,
      requiresSubjectNamePrompt: hasRootFilesWithoutSubject,
    );
  }

  /// Checks for zip-slip vulnerability: absolute paths or path traversal (..)
  static bool _isZipSlip(String path) {
    if (path.startsWith('/') || path.startsWith('\\')) return true;
    if (RegExp(r'^[a-zA-Z]:').hasMatch(path)) return true; // Windows drive letters
    final normalized = p.normalize(path);
    if (normalized == '..' || normalized.startsWith('../') || normalized.startsWith('..\\')) {
      return true;
    }
    return false;
  }

  /// Checks if the path is a system file or hidden metadata
  static bool _isSystemOrHidden(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('__macosx/') || lower.startsWith('__macosx')) return true;
    final base = p.basename(path).toLowerCase();
    if (base.startsWith('.')) return true;
    if (ignoredFilenames.contains(base)) return true;
    return false;
  }

  /// Determines whether a file represents a practical experiment or lecture note.
  static bool _isPracticalFile(List<String> segments, bool isDirectUnderSubject) {
    // Check folder names in path
    for (int i = 0; i < segments.length - 1; i++) {
      final folder = segments[i].toLowerCase();
      if (folder == 'practicals' ||
          folder == 'practical' ||
          folder == 'lab' ||
          folder == 'labs' ||
          folder.contains('practical') ||
          folder.contains('lab')) {
        return true;
      }
    }

    // Check filename
    final fileName = segments.last.toLowerCase();
    final nameWithoutExt = p.basenameWithoutExtension(fileName);
    if (RegExp(r'(?:^|[_\s.-])(practical|practicals|lab|labs|exp|experiment|experiments)(?:[_\s.-]|\d|$)', caseSensitive: false).hasMatch(nameWithoutExt) ||
        nameWithoutExt.startsWith('p_') ||
        nameWithoutExt.startsWith('exp_')) {
      return true;
    }

    // Check code extensions commonly used for practicals
    final ext = p.extension(fileName).toLowerCase();
    if (['.java', '.cpp', '.c', '.py', '.sql', '.dart'].contains(ext)) {
      return true;
    }

    return false;
  }

  /// Parses unit number and title from a unit folder string (e.g. "Unit 1 - Introduction" -> (1, "Introduction"))
  static ({int number, String title}) _parseUnitInfo(String folder) {
    if (folder.toLowerCase() == 'general') {
      return (number: 1, title: 'General');
    }

    // Regex matching "Unit 1", "Unit-2", "Unit_3", "U4", "Module 1"
    final match = RegExp(r'^(?:Unit|U|Module)[\s_-]*(\d+)(?:[\s._-]*(?:-|:|\.)?[\s._-]*(.*))?$', caseSensitive: false)
        .firstMatch(folder.trim());

    if (match != null) {
      final numStr = match.group(1);
      final number = int.tryParse(numStr ?? '1') ?? 1;
      var title = match.group(2)?.trim() ?? '';
      title = title.replaceFirst(RegExp(r'^[\s.:_-]+'), '').trim();
      if (title.isEmpty) {
        title = 'Unit $number';
      }
      return (number: number, title: _sanitizeName(title));
    }

    return (number: 1, title: _sanitizeName(folder));
  }

  /// Sanitizes string removing invalid filesystem or display characters
  static String _sanitizeName(String input) {
    return input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static _UnitAccumulator _getOrCreateUnit(
    Map<String, Map<String, _UnitAccumulator>> subjectsMap,
    String subjectName,
    String unitFolder,
  ) {
    final units = subjectsMap.putIfAbsent(subjectName, () => {});
    return units.putIfAbsent(unitFolder, () => _UnitAccumulator());
  }
}

class _UnitAccumulator {
  final List<ParsedFile> notes = [];
  final List<ParsedFile> practicals = [];
  final List<ParsedQuestion> questions = [];
}
