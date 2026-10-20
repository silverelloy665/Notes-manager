import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/summary_model.dart';

/// Service providing export capabilities for Anki flashcards and printable PDF study sheets.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Generates Anki-compatible TSV/CSV format with HTML formatting and tags.
  ///
  /// Can be directly imported into Anki via File -> Import.
  String generateAnkiCsv(List<Question> questions) {
    final buffer = StringBuffer();
    // Anki Header Directives
    buffer.writeln('#separator:Tab');
    buffer.writeln('#html:true');
    buffer.writeln('#tags column:3');

    for (final q in questions) {
      // 1. Front Side
      final frontBuffer = StringBuffer();
      frontBuffer.write('<div style="font-family:serif;font-size:16px;color:#2E4F4F;"><b>${_escapeHtml(q.question)}</b></div>');
      if (q.subtopic != null && q.subtopic!.isNotEmpty) {
        frontBuffer.write('<div style="font-size:12px;color:#0E8388;margin-top:4px;"><i>Subtopic: ${_escapeHtml(q.subtopic!)}</i></div>');
      }

      if (q.isMcq && q.options != null) {
        frontBuffer.write('<div style="margin-top:12px;font-size:14px;color:#2C3333;">');
        for (int i = 0; i < q.options!.length; i++) {
          final letter = String.fromCharCode(65 + i);
          frontBuffer.write('<div style="margin-bottom:4px;"><b>$letter)</b> ${_escapeHtml(q.options![i])}</div>');
        }
        frontBuffer.write('</div>');
      }
      final front = frontBuffer.toString().replaceAll('\t', ' ').replaceAll('\n', '<br>');

      // 2. Back Side
      final backBuffer = StringBuffer();
      if (q.isMcq && q.options != null && q.correctOptionIndex != null) {
        final correctLetter = String.fromCharCode(65 + q.correctOptionIndex!);
        final correctText = q.correctOptionIndex! < q.options!.length ? q.options![q.correctOptionIndex!] : '';
        backBuffer.write('<div style="font-size:15px;color:#2E7D32;"><b>Correct Answer: $correctLetter) ${_escapeHtml(correctText)}</b></div>');
      } else {
        backBuffer.write('<div style="font-size:15px;color:#2E7D32;"><b>Model Answer:</b><br>${_escapeHtml(q.answer)}</div>');
      }

      if (q.explanation != null && q.explanation!.isNotEmpty) {
        backBuffer.write('<div style="margin-top:8px;font-size:13px;color:#333333;"><b>Explanation:</b> ${_escapeHtml(q.explanation!)}</div>');
      }

      if (q.distractorReasoning != null && q.distractorReasoning!.isNotEmpty) {
        backBuffer.write('<div style="margin-top:8px;font-size:12px;color:#666666;"><b>Distractor Analysis:</b>');
        q.distractorReasoning!.forEach((opt, reason) {
          backBuffer.write('<br>• <b>$opt:</b> ${_escapeHtml(reason)}');
        });
        backBuffer.write('</div>');
      }

      if (q.keyPointsRubric != null && q.keyPointsRubric!.isNotEmpty) {
        backBuffer.write('<div style="margin-top:8px;font-size:12px;color:#0E8388;"><b>Key Rubric Points:</b>');
        for (final pt in q.keyPointsRubric!) {
          backBuffer.write('<br>✓ ${_escapeHtml(pt)}');
        }
        backBuffer.write('</div>');
      }

      if (q.sourcePage != null) {
        backBuffer.write('<div style="margin-top:6px;font-size:11px;color:#888888;"><i>Source Reference: Slide/Page ${q.sourcePage}</i></div>');
      }
      final back = backBuffer.toString().replaceAll('\t', ' ').replaceAll('\n', '<br>');

      // 3. Tags
      final cleanTopic = q.topic.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final subtopicTag = (q.subtopic != null && q.subtopic!.isNotEmpty)
          ? ' $cleanTopic::${q.subtopic!.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}'
          : '';
      final tags = 'NotesManager $cleanTopic$subtopicTag Difficulty_${q.difficulty ?? "Medium"} Bloom_${q.bloomLevel ?? "Understand"}';

      buffer.writeln('$front\t$back\t$tags');
    }

    return buffer.toString();
  }

  /// Generates a printable Study Sheet PDF with questions on the front and verified answers/rubrics on the back.
  Future<List<int>> generateStudySheetPdf({
    required String title,
    required String topic,
    required List<Question> questions,
    bool includeAnswerKey = true,
  }) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    // Colors
    final primaryColor = PdfColor(46, 79, 79); // Sage/Forest
    final secondaryColor = PdfColor(14, 131, 136); // Teal accent
    final textColor = PdfColor(44, 51, 51);
    final subtleColor = PdfColor(120, 120, 120);

    // Fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final bodyBold = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.italic);

    // Page 1: Questions Section
    var page = document.pages.add();
    var graphics = page.graphics;
    double y = 10;

    // Header Title
    graphics.drawString('STUDYMATE ACADEMIC PRACTICE SHEET', titleFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 24));
    y += 24;
    graphics.drawString('Topic: $topic • Document: $title', sectionFont, brush: PdfSolidBrush(secondaryColor), bounds: Rect.fromLTWH(0, y, 500, 18));
    y += 20;
    graphics.drawLine(PdfPen(secondaryColor, width: 1.2), Offset(0, y), Offset(540, y));
    y += 14;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      // Check for page overflow
      if (y > 700) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      // Question Number & Text
      final qHeader = 'Q${i + 1}. [${q.difficulty ?? "Medium"} • ${q.bloomLevel ?? "Understand"}] ${q.subtopic != null ? "(${q.subtopic}) " : ""}${q.question}';
      graphics.drawString(
        qHeader,
        bodyBold,
        brush: PdfSolidBrush(textColor),
        bounds: Rect.fromLTWH(0, y, 530, 40),
        format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.top),
      );
      y += (qHeader.length > 90) ? 30.0 : 18.0;

      if (q.isMcq && q.options != null) {
        for (int optIdx = 0; optIdx < q.options!.length; optIdx++) {
          final letter = String.fromCharCode(65 + optIdx);
          graphics.drawString(
            '   $letter) ${q.options![optIdx]}',
            bodyFont,
            brush: PdfSolidBrush(textColor),
            bounds: Rect.fromLTWH(0, y, 520, 16),
          );
          y += 14;
        }
        y += 6;
      } else {
        // Conceptual blank answer lines
        graphics.drawString('   Answer / Notes: ____________________________________________________________________', smallFont, brush: PdfSolidBrush(subtleColor), bounds: Rect.fromLTWH(0, y, 520, 14));
        y += 14;
        graphics.drawString('   ____________________________________________________________________________________', smallFont, brush: PdfSolidBrush(subtleColor), bounds: Rect.fromLTWH(0, y, 520, 14));
        y += 18;
      }
    }

    // Answer Key Section (New Page)
    if (includeAnswerKey) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 15;

      graphics.drawString('VERIFIED ANSWER KEY & RUBRICS', titleFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 24));
      y += 24;
      graphics.drawString('Ground-Truth Answers Grounded in Course Material', sectionFont, brush: PdfSolidBrush(secondaryColor), bounds: Rect.fromLTWH(0, y, 500, 18));
      y += 20;
      graphics.drawLine(PdfPen(secondaryColor, width: 1.2), Offset(0, y), Offset(540, y));
      y += 16;

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];

        if (y > 700) {
          page = document.pages.add();
          graphics = page.graphics;
          y = 20;
        }

        String ansLine;
        if (q.isMcq && q.options != null && q.correctOptionIndex != null) {
          final letter = String.fromCharCode(65 + q.correctOptionIndex!);
          final text = q.correctOptionIndex! < q.options!.length ? q.options![q.correctOptionIndex!] : '';
          ansLine = 'Q${i + 1}. Correct Answer: $letter) $text';
        } else {
          ansLine = 'Q${i + 1}. Model Answer: ${q.answer}';
        }

        graphics.drawString(ansLine, bodyBold, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 530, 28));
        y += 20;

        if (q.explanation != null && q.explanation!.isNotEmpty) {
          graphics.drawString('   Explanation: ${q.explanation!}', bodyFont, brush: PdfSolidBrush(textColor), bounds: Rect.fromLTWH(0, y, 520, 32));
          y += 22;
        }

        if (q.sourcePage != null) {
          graphics.drawString('   Grounded Source Reference: Slide/Page ${q.sourcePage}', smallFont, brush: PdfSolidBrush(subtleColor), bounds: Rect.fromLTWH(0, y, 520, 14));
          y += 16;
        }
        y += 6;
      }
    }

    final bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  /// Generates a printable Exam Cheat Sheet PDF containing definitions, formulas, and high-yield takeaways.
  Future<List<int>> generateCheatSheetPdf({
    required String title,
    required String topic,
    required MultiLevelSummary summary,
  }) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36;

    final primaryColor = PdfColor(46, 79, 79);
    final secondaryColor = PdfColor(14, 131, 136);
    final textColor = PdfColor(44, 51, 51);

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);

    var page = document.pages.add();
    var graphics = page.graphics;
    double y = 10;

    graphics.drawString('EXAM CHEAT SHEET & HIGH-YIELD SUMMARY', titleFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 24));
    y += 22;
    graphics.drawString('$topic • $title', sectionFont, brush: PdfSolidBrush(secondaryColor), bounds: Rect.fromLTWH(0, y, 500, 16));
    y += 18;
    graphics.drawLine(PdfPen(secondaryColor, width: 1.2), Offset(0, y), Offset(540, y));
    y += 14;

    // TL;DR
    graphics.drawString('⚡ ONE-LINE TL;DR', sectionFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 16));
    y += 16;
    graphics.drawString(summary.tldr, bodyFont, brush: PdfSolidBrush(textColor), bounds: Rect.fromLTWH(0, y, 530, 32));
    y += 30;

    // 5 High-Yield Points
    graphics.drawString('🔑 5 HIGH-YIELD TAKEAWAYS', sectionFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 16));
    y += 16;
    for (final kp in summary.keyPoints) {
      graphics.drawString('• $kp', bodyFont, brush: PdfSolidBrush(textColor), bounds: Rect.fromLTWH(0, y, 530, 20));
      y += 16;
    }
    y += 10;

    // Core Definitions
    if (summary.cheatSheet.definitions.isNotEmpty) {
      graphics.drawString('📌 CORE DEFINITIONS', sectionFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 16));
      y += 16;
      for (final def in summary.cheatSheet.definitions.take(8)) {
        if (y > 710) {
          page = document.pages.add();
          graphics = page.graphics;
          y = 20;
        }
        graphics.drawString('• ${def.term}: ${def.definition}', bodyFont, brush: PdfSolidBrush(textColor), bounds: Rect.fromLTWH(0, y, 530, 22));
        y += 18;
      }
      y += 10;
    }

    // High Yield Tips
    if (summary.cheatSheet.highYieldTips.isNotEmpty) {
      if (y > 680) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }
      graphics.drawString('🎯 EXAM TIPS & PITFALLS', sectionFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, 500, 16));
      y += 16;
      for (final tip in summary.cheatSheet.highYieldTips.take(5)) {
        graphics.drawString('✓ $tip', bodyFont, brush: PdfSolidBrush(textColor), bounds: Rect.fromLTWH(0, y, 530, 20));
        y += 16;
      }
    }

    final bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  /// Saves the exported file to device storage and opens it if supported.
  Future<String?> saveAndOpenFile({required String fileName, required List<int> bytes}) async {
    try {
      Directory? dir;
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        return null;
      }

      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Attempt to open file
      try {
        await OpenFilex.open(file.path);
      } catch (_) {}

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Generates a CSV export of the enrolled student roster with performance summaries.
  String generateRosterCsv(Classroom classroom, List<StudentGradeSummary> students) {
    final buffer = StringBuffer();
    buffer.writeln('Classroom Name,${_escapeCsv(classroom.name)}');
    buffer.writeln('Subject,${_escapeCsv(classroom.subject)}');
    buffer.writeln('Join Code,${classroom.code}');
    buffer.writeln('Total Students,${students.length}');
    buffer.writeln('');
    buffer.writeln('Student ID,Student Name,Email,Phone,Assessments Taken,Total Marks Obtained,Max Marks,Overall Percentage');
    for (final s in students) {
      buffer.writeln(
        '${_escapeCsv(s.studentId)},'
        '${_escapeCsv(s.studentName)},'
        '${_escapeCsv(s.studentEmail)},'
        '${_escapeCsv(s.studentPhone)},'
        '${s.assessmentsCount},'
        '${s.totalObtained.toStringAsFixed(1)},'
        '${s.totalMax.toStringAsFixed(1)},'
        '${s.percentage.toStringAsFixed(1)}%',
      );
    }
    return buffer.toString();
  }

  /// Generates a CSV string representing classroom questions.
  String generateQuestionBankCsv(List<Question> questions) {
    final buffer = StringBuffer();
    buffer.writeln('Topic,Unit,Type,Difficulty,Bloom,Marks,Negative Marks,Question,Answer,Option A,Option B,Option C,Option D,Correct Option,Explanation,Tags,Source Note,Source Page');
    for (final q in questions) {
      final optA = (q.options != null && q.options!.isNotEmpty) ? q.options![0] : '';
      final optB = (q.options != null && q.options!.length > 1) ? q.options![1] : '';
      final optC = (q.options != null && q.options!.length > 2) ? q.options![2] : '';
      final optD = (q.options != null && q.options!.length > 3) ? q.options![3] : '';
      final correctOpt = q.correctOptionIndex != null
          ? String.fromCharCode(65 + q.correctOptionIndex!)
          : (q.correctOptionIndices != null && q.correctOptionIndices!.isNotEmpty
              ? q.correctOptionIndices!.map((i) => String.fromCharCode(65 + i)).join(';')
              : '');

      buffer.writeln([
        _escapeCsv(q.topic),
        q.unitNumber?.toString() ?? '',
        _escapeCsv(q.questionType),
        _escapeCsv(q.difficulty ?? 'Medium'),
        _escapeCsv(q.bloomLevel ?? 'Understand'),
        q.marks.toString(),
        q.negativeMarks.toString(),
        _escapeCsv(q.question),
        _escapeCsv(q.answer),
        _escapeCsv(optA),
        _escapeCsv(optB),
        _escapeCsv(optC),
        _escapeCsv(optD),
        _escapeCsv(correctOpt),
        _escapeCsv(q.explanation ?? ''),
        _escapeCsv(q.tags.join(';')),
        _escapeCsv(q.documentId ?? ''),
        q.sourcePage?.toString() ?? '',
      ].join(','));
    }
    return buffer.toString();
  }

  /// Parses a CSV string into a list of Question objects.
  List<Question> parseQuestionBankCsv(String csvContent, {String? classroomId, String? defaultTopic}) {
    final lines = _splitCsvLines(csvContent);
    if (lines.length <= 1) return [];

    final questions = <Question>[];
    for (int i = 1; i < lines.length; i++) {
      final row = _parseCsvRow(lines[i]);
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      final topic = (row.isNotEmpty && row[0].trim().isNotEmpty) ? row[0].trim() : (defaultTopic ?? 'General');
      final unit = row.length > 1 ? int.tryParse(row[1].trim()) : null;
      final type = row.length > 2 && row[2].trim().isNotEmpty ? row[2].trim().toLowerCase() : 'mcq';
      final difficulty = row.length > 3 && row[3].trim().isNotEmpty ? row[3].trim() : 'Medium';
      final bloom = row.length > 4 && row[4].trim().isNotEmpty ? row[4].trim() : 'Understand';
      final marks = row.length > 5 ? (double.tryParse(row[5].trim()) ?? 1.0) : 1.0;
      final negMarks = row.length > 6 ? (double.tryParse(row[6].trim()) ?? 0.0) : 0.0;
      final questionText = row.length > 7 ? row[7].trim() : '';
      final answerText = row.length > 8 ? row[8].trim() : '';

      final optA = row.length > 9 ? row[9].trim() : '';
      final optB = row.length > 10 ? row[10].trim() : '';
      final optC = row.length > 11 ? row[11].trim() : '';
      final optD = row.length > 12 ? row[12].trim() : '';
      final correctStr = row.length > 13 ? row[13].trim().toUpperCase() : '';
      final explanation = row.length > 14 ? row[14].trim() : '';
      final tagsStr = row.length > 15 ? row[15].trim() : '';
      final docId = row.length > 16 && row[16].trim().isNotEmpty ? row[16].trim() : null;
      final sourcePage = row.length > 17 ? int.tryParse(row[17].trim()) : null;

      if (questionText.isEmpty) continue;

      List<String>? options;
      int? correctOptionIndex;
      final opts = [optA, optB, optC, optD].where((o) => o.isNotEmpty).toList();
      if (opts.isNotEmpty) {
        options = opts;
        if (correctStr.isNotEmpty) {
          final charCode = correctStr.codeUnitAt(0);
          if (charCode >= 65 && charCode <= 68) {
            correctOptionIndex = charCode - 65;
          } else {
            correctOptionIndex = int.tryParse(correctStr);
          }
        }
      }

      final tags = tagsStr.isNotEmpty
          ? tagsStr.split(';').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      questions.add(
        Question(
          id: '',
          topic: topic,
          question: questionText,
          answer: answerText.isNotEmpty
              ? answerText
              : (options != null && correctOptionIndex != null && correctOptionIndex < options.length
                  ? options[correctOptionIndex]
                  : 'True'),
          options: options,
          correctOptionIndex: correctOptionIndex,
          unitNumber: unit,
          questionType: type,
          difficulty: difficulty,
          bloomLevel: bloom,
          marks: marks,
          negativeMarks: negMarks,
          explanation: explanation.isNotEmpty ? explanation : null,
          tags: tags,
          documentId: docId,
          sourcePage: sourcePage,
          classroomId: classroomId,
          createdAt: DateTime.now(),
        ),
      );
    }
    return questions;
  }

  static List<String> _splitCsvLines(String text) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        inQuote = !inQuote;
        buffer.write(char);
      } else if ((char == '\n' || char == '\r') && !inQuote) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n in CRLF
        }
        if (buffer.isNotEmpty) {
          lines.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }
    return lines;
  }

  static List<String> _parseCsvRow(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (char == ',' && !inQuote) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static String _escapeCsv(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
