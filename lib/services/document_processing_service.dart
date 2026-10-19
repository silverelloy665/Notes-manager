import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/constants.dart';

/// Represents a parsed section within an uploaded document.
class DocumentSection {
  final String title;
  final String content;

  const DocumentSection({
    required this.title,
    required this.content,
  });
}

/// Represents the extracted structured content from an uploaded PDF or ZIP file.
class ProcessedDocument {
  final String fileName;
  final String fileType; // 'pdf', 'zip', 'txt', 'md'
  final String detectedTitle;
  final String detectedTopic;
  final String fullText;
  final List<DocumentSection> sections;
  final List<String> extractedFiles; // If ZIP, names of files processed

  const ProcessedDocument({
    required this.fileName,
    required this.fileType,
    required this.detectedTitle,
    required this.detectedTopic,
    required this.fullText,
    required this.sections,
    this.extractedFiles = const [],
  });
}

/// Extracts clean, structured text and topics from PDFs, ZIP archives, and text notes.
class DocumentProcessingService {
  DocumentProcessingService._();
  static final DocumentProcessingService instance = DocumentProcessingService._();

  /// Processes either a PDF, ZIP, or text file from in-memory bytes.
  Future<ProcessedDocument> processBytes({
    required List<int> bytes,
    required String fileName,
    String? preferredTopic,
  }) async {
    final ext = p.extension(fileName).toLowerCase();

    if (ext == '.pdf') {
      return _processPdf(bytes, fileName, preferredTopic: preferredTopic);
    } else if (ext == '.zip') {
      return _processZip(bytes, fileName, preferredTopic: preferredTopic);
    } else {
      return _processPlainText(bytes, fileName, ext, preferredTopic: preferredTopic);
    }
  }

  /// Extracts text from a PDF file using page-by-page extraction to identify slides/topics.
  ProcessedDocument _processPdf(List<int> bytes, String fileName, {String? preferredTopic}) {
    String extractedText = '';
    PdfDocument? document;
    final List<DocumentSection> sections = [];

    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;

      for (int i = 0; i < pageCount; i++) {
        try {
          final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          final cleanPageText = _cleanText(pageText);
          if (cleanPageText.trim().isNotEmpty) {
            final pageTitle = _inferSlideOrSectionTitle(cleanPageText, i + 1);
            sections.add(DocumentSection(title: pageTitle, content: cleanPageText));
          }
        } catch (_) {}
      }

      extractedText = extractor.extractText();
    } catch (e) {
      extractedText = 'Unable to extract full text from PDF: $e';
    } finally {
      document?.dispose();
    }

    final cleanText = _cleanText(extractedText);
    if (sections.isEmpty) {
      sections.addAll(_extractSectionsFromText(cleanText));
    }

    final detectedTitle = _inferTitle(cleanText, fileName);
    String detectedTopic = _detectAcademicTopic('$fileName\n$cleanText');
    if ((detectedTopic == 'Other' || detectedTopic.isEmpty) &&
        preferredTopic != null &&
        preferredTopic != 'All' &&
        preferredTopic != 'All Topics') {
      detectedTopic = preferredTopic;
    }

    return ProcessedDocument(
      fileName: fileName,
      fileType: 'pdf',
      detectedTitle: detectedTitle,
      detectedTopic: detectedTopic,
      fullText: cleanText,
      sections: sections,
    );
  }

  /// Infers a slide or section title from a single page of text.
  String _inferSlideOrSectionTitle(String text, int pageNumber) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('===') && !l.startsWith('---'))
        .toList();

    for (int i = 0; i < lines.length && i < 5; i++) {
      var line = lines[i];
      // Merge with next line if unclosed bracket exists (e.g. "Assignment (" + "Research Activity)")
      if (line.contains('(') && !line.contains(')') && i + 1 < lines.length) {
        line = '$line ${lines[i + 1]}';
      }
      var cleaned = line.replaceAll(RegExp(r'^[#*=\-\d.\s]+'), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{:\-,]+$'), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

      final lower = cleaned.toLowerCase();
      if (cleaned.length >= 3 &&
          cleaned.length <= 55 &&
          !lower.startsWith('lorem ipsum') &&
          !lower.startsWith('http') &&
          !lower.startsWith('page ') &&
          !lower.startsWith('by ') &&
          !lower.startsWith('last date') &&
          !lower.startsWith('submission')) {
        return cleaned;
      }
    }

    // Check last line if title appeared at the bottom of OCR text
    if (lines.length > 1) {
      var lastLine = lines.last.replaceAll(RegExp(r'^[#*=\-\d.\s]+'), '').trim();
      lastLine = lastLine.replaceAll(RegExp(r'[\(\[\{:\-,]+$'), '').trim();
      final lower = lastLine.toLowerCase();
      if (lastLine.length >= 3 &&
          lastLine.length <= 55 &&
          !lower.startsWith('lorem ipsum') &&
          !lower.startsWith('last date')) {
        return lastLine;
      }
    }

    return 'Topic $pageNumber';
  }

  /// Extracts notes and text from a ZIP archive.
  ProcessedDocument _processZip(List<int> bytes, String fileName, {String? preferredTopic}) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (e) {
      archive = Archive();
    }

    final StringBuffer fullTextBuffer = StringBuffer();
    final List<DocumentSection> sections = [];
    final List<String> extractedFiles = [];

    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      final ext = p.extension(name).toLowerCase();

      // Skip system or executable files
      if (name.startsWith('__MACOSX') ||
          name.contains('.DS_Store') ||
          ext == '.exe' ||
          ext == '.bat' ||
          ext == '.apk') {
        continue;
      }

      final fileBytes = file.content as List<int>;
      String fileText = '';

      if (ext == '.pdf') {
        PdfDocument? doc;
        try {
          doc = PdfDocument(inputBytes: fileBytes);
          fileText = PdfTextExtractor(doc).extractText();
        } catch (_) {
          fileText = '';
        } finally {
          doc?.dispose();
        }
      } else if (['.txt', '.md', '.json', '.dart', '.py', '.java', '.cpp', '.c', '.html', '.js'].contains(ext)) {
        try {
          fileText = utf8.decode(fileBytes, allowMalformed: true);
        } catch (_) {
          fileText = '';
        }
      }

      final cleanFileText = _cleanText(fileText);
      if (cleanFileText.trim().isNotEmpty) {
        extractedFiles.add(p.basename(name));
        final sectionTitle = p.basenameWithoutExtension(name);
        sections.add(DocumentSection(title: sectionTitle, content: cleanFileText));
        fullTextBuffer.writeln('=== File: $name ===');
        fullTextBuffer.writeln(cleanFileText);
        fullTextBuffer.writeln();
      }
    }

    final fullText = fullTextBuffer.toString();
    final cleanFullText = fullText.isNotEmpty ? fullText : 'Archive containing ${extractedFiles.length} files.';
    final detectedTitle = _inferTitle(cleanFullText, fileName);
    String detectedTopic = _detectAcademicTopic('$fileName\n$cleanFullText');
    if ((detectedTopic == 'Other' || detectedTopic.isEmpty) &&
        preferredTopic != null &&
        preferredTopic != 'All' &&
        preferredTopic != 'All Topics') {
      detectedTopic = preferredTopic;
    }

    return ProcessedDocument(
      fileName: fileName,
      fileType: 'zip',
      detectedTitle: detectedTitle,
      detectedTopic: detectedTopic,
      fullText: cleanFullText,
      sections: sections,
      extractedFiles: extractedFiles,
    );
  }

  /// Handles plain text or markdown files.
  ProcessedDocument _processPlainText(List<int> bytes, String fileName, String ext, {String? preferredTopic}) {
    String text = '';
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }

    final cleanText = _cleanText(text);
    final sections = _extractSectionsFromText(cleanText);
    final detectedTitle = _inferTitle(cleanText, fileName);
    String detectedTopic = _detectAcademicTopic('$fileName\n$cleanText');
    if ((detectedTopic == 'Other' || detectedTopic.isEmpty) &&
        preferredTopic != null &&
        preferredTopic != 'All' &&
        preferredTopic != 'All Topics') {
      detectedTopic = preferredTopic;
    }

    return ProcessedDocument(
      fileName: fileName,
      fileType: ext.replaceAll('.', ''),
      detectedTitle: detectedTitle,
      detectedTopic: detectedTopic,
      fullText: cleanText,
      sections: sections,
    );
  }

  /// Cleans up raw extracted text (excess spaces, repeated newlines, form-feeds).
  String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\f+'), '\n')
        .replaceAll(RegExp(r'\t+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'\bSoft\s+ware\b', caseSensitive: false), 'Software')
        .replaceAll(RegExp(r'\bmethod\s+s\b', caseSensitive: false), 'methods')
        .replaceAll(RegExp(r'(\d)\s+/\s+(\d)\s+/\s+(\d)'), r'$1/$2/$3')
        .replaceAll(RegExp(r'\(\s+'), '(')
        .replaceAll(RegExp(r'\s+\)'), ')')
        .trim();
  }

  /// Infers a human-readable title from the content or filename.
  String _inferTitle(String text, String fileName) {
    final base = p.basenameWithoutExtension(fileName)
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Check first non-empty line of text for heading
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final firstLine = lines.first.replaceAll(RegExp(r'^[#*=\-\s]+'), '').trim();
      if (firstLine.length > 3 && firstLine.length < 80 && !firstLine.startsWith('===')) {
        return firstLine;
      }
    }

    if (base.isNotEmpty) {
      // Capitalize words
      return base.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }

    return 'Lecture Notes';
  }

  /// Analyzes text and assigns the best-matching topic from [AppConstants.topics].
  String _detectAcademicTopic(String text) {
    final lower = text.toLowerCase();

    final topicScores = <String, int>{};

    final keywords = <String, List<String>>{
      'Operating Systems': [
        'operating system', 'kernel', 'process', 'thread', 'deadlock', 'scheduling',
        'semaphore', 'mutex', 'virtual memory', 'paging', 'page fault', 'context switch',
        'file system', 'fork', 'pipe', 'concurrency', 'critical section', 'round robin'
      ],
      'Database Management': [
        'database', 'dbms', 'sql', 'rdbms', 'relation', 'table', 'foreign key', 'primary key',
        'normalization', '1nf', '2nf', '3nf', 'bcnf', 'acid', 'transaction', 'schema',
        'join', 'index', 'nosql', 'query'
      ],
      'Computer Networks': [
        'network', 'tcp', 'udp', 'ip address', 'osi model', 'packet', 'router', 'switch',
        'dns', 'http', 'https', 'protocol', 'ethernet', 'bandwidth', 'latency', 'subnet',
        'socket', 'arp', 'icmp', 'tls', 'port'
      ],
      'Design & Analysis of Algorithms': [
        'algorithm', 'time complexity', 'space complexity', 'big o', 'binary search',
        'dynamic programming', 'greedy', 'divide and conquer', 'graph', 'tree', 'sorting',
        'dijkstra', 'bfs', 'dfs', 'recurrence', 'asymptotic'
      ],
      'Object Oriented Programming': [
        'object oriented', 'oop', 'class', 'object', 'inheritance', 'polymorphism',
        'encapsulation', 'abstraction', 'interface', 'constructor', 'destructor',
        'method overriding', 'overloading'
      ],
      'Software Engineering': [
        'software engineering', 'software development', 'agile', 'scrum', 'waterfall',
        'sdlc', 'requirements', 'specification', 'research activity', 'assignment',
        'proposed method', 'advantages', 'disadvantages', 'testing', 'uml', 'design pattern',
        'verification', 'validation', 'architecture'
      ],
      'Web Programming': [
        'web programming', 'html', 'css', 'javascript', 'typescript', 'frontend',
        'backend', 'dom', 'rest api', 'json', 'client', 'server', 'async', 'promise'
      ],
      'Computer Organization & Architecture': [
        'computer organization', 'architecture', 'cpu', 'alu', 'register', 'cache',
        'pipelining', 'instruction set', 'mips', 'risc', 'cisc', 'bus', 'control unit',
        'memory hierarchy', 'hazard'
      ],
      'Microprocessors & Microcontrollers': [
        'microprocessor', 'microcontroller', '8085', '8086', 'arm', 'gpio', 'interrupt',
        'pin diagram', 'timer', 'analog', 'digital', 'embedded', 'adc', 'dac'
      ],
      'Mathematics': [
        'matrix', 'determinant', 'calculus', 'derivative', 'integration', 'probability',
        'statistics', 'linear algebra', 'eigenvalue', 'vector', 'differential equation',
        'theorem', 'lemma'
      ],
      'Physics': [
        'physics', 'velocity', 'acceleration', 'force', 'energy', 'thermodynamics',
        'electromagnetism', 'quantum', 'optics', 'wave', 'current', 'voltage', 'resistance'
      ],
    };

    keywords.forEach((topic, words) {
      int score = 0;
      for (final word in words) {
        final matches = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false).allMatches(lower);
        score += matches.length * (word.split(' ').length > 1 ? 3 : 1);
      }
      topicScores[topic] = score;
    });

    String bestTopic = 'Other';
    int maxScore = 0;
    topicScores.forEach((topic, score) {
      if (score > maxScore) {
        maxScore = score;
        bestTopic = topic;
      }
    });

    return maxScore > 0 ? bestTopic : 'Other';
  }

  /// Splits content into sections based on headings or paragraphs.
  List<DocumentSection> _extractSectionsFromText(String text) {
    final sections = <DocumentSection>[];
    final lines = text.split('\n');

    String currentHeading = 'Overview';
    final currentContent = StringBuffer();

    final headingRegex = RegExp(r'^(?:#{1,4}\s+|[0-9]+(?:\.[0-9]+)*\s+|Unit\s+\d+|Chapter\s+\d+|Topic:\s*)(.+)$', caseSensitive: false);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        currentContent.writeln();
        continue;
      }

      final match = headingRegex.firstMatch(trimmed);
      if (match != null && trimmed.length < 80) {
        if (currentContent.toString().trim().isNotEmpty) {
          sections.add(DocumentSection(
            title: currentHeading,
            content: currentContent.toString().trim(),
          ));
          currentContent.clear();
        }
        currentHeading = match.group(1)?.trim() ?? trimmed;
      } else {
        currentContent.writeln(trimmed);
      }
    }

    if (currentContent.toString().trim().isNotEmpty) {
      sections.add(DocumentSection(
        title: currentHeading,
        content: currentContent.toString().trim(),
      ));
    }

    if (sections.isEmpty && text.trim().isNotEmpty) {
      sections.add(DocumentSection(title: 'Overview', content: text.trim()));
    }

    return sections;
  }
}

