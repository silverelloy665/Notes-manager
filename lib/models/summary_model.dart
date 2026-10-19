/// Data model representing a multi-level structured academic summary.
/// Supports Map-Reduce aggregation across every topic/subtopic in a document.
class MultiLevelSummary {
  final String documentTitle;
  final String topic;
  final String tldr; // (a) One-line TL;DR
  final List<String> keyPoints; // (b) 5-bullet key points
  final List<SectionSummary> sections; // (c) Detailed section-by-section breakdown
  final ExamCheatSheet cheatSheet; // (d) "Exam cheat sheet" (definitions, formulas, key terms)
  final Map<String, String> glossary; // (e) Glossary of terms
  final List<TeacherQuestion> qaSummary; // (f) Q&A Summary (5 teacher questions)
  final String mindMapMermaid; // Visual Mind Map in Mermaid syntax
  final String tone; // 'academic', 'simple'
  final String length; // 'concise', 'detailed', 'comprehensive'
  final String language; // 'en', 'hi', etc.
  final String contentHash; // SHA-256 cache key
  final bool isVerified; // Validation pass verified
  final List<String> validationNotes; // Verification audit logs

  const MultiLevelSummary({
    required this.documentTitle,
    required this.topic,
    required this.tldr,
    required this.keyPoints,
    required this.sections,
    required this.cheatSheet,
    required this.glossary,
    this.qaSummary = const [],
    required this.mindMapMermaid,
    this.tone = 'academic',
    this.length = 'detailed',
    this.language = 'en',
    this.contentHash = '',
    this.isVerified = true,
    this.validationNotes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'documentTitle': documentTitle,
      'topic': topic,
      'tldr': tldr,
      'keyPoints': keyPoints,
      'sections': sections.map((s) => s.toMap()).toList(),
      'cheatSheet': cheatSheet.toMap(),
      'glossary': glossary,
      'qaSummary': qaSummary.map((q) => q.toMap()).toList(),
      'mindMapMermaid': mindMapMermaid,
      'tone': tone,
      'length': length,
      'language': language,
      'contentHash': contentHash,
      'isVerified': isVerified,
      'validationNotes': validationNotes,
    };
  }

  factory MultiLevelSummary.fromMap(Map<String, dynamic> map) {
    return MultiLevelSummary(
      documentTitle: (map['documentTitle'] ?? '') as String,
      topic: (map['topic'] ?? 'General') as String,
      tldr: (map['tldr'] ?? '') as String,
      keyPoints: List<String>.from(map['keyPoints'] ?? []),
      sections: (map['sections'] as List<dynamic>? ?? [])
          .map((s) => SectionSummary.fromMap(s as Map<String, dynamic>))
          .toList(),
      cheatSheet: ExamCheatSheet.fromMap(map['cheatSheet'] as Map<String, dynamic>? ?? {}),
      glossary: Map<String, String>.from(map['glossary'] ?? {}),
      qaSummary: (map['qaSummary'] as List<dynamic>? ?? [])
          .map((q) => TeacherQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      mindMapMermaid: (map['mindMapMermaid'] ?? '') as String,
      tone: (map['tone'] ?? 'academic') as String,
      length: (map['length'] ?? 'detailed') as String,
      language: (map['language'] ?? 'en') as String,
      contentHash: (map['contentHash'] ?? '') as String,
      isVerified: (map['isVerified'] ?? true) as bool,
      validationNotes: List<String>.from(map['validationNotes'] ?? []),
    );
  }

  /// Exports full multi-level summary into structured botanical Markdown.
  String toMarkdown({bool includeSources = true}) {
    final sb = StringBuffer();
    sb.writeln('# $documentTitle');
    sb.writeln('**Subject / Topic:** $topic');
    sb.writeln();

    // (a) One-line TL;DR
    sb.writeln('## ⚡ One-Line TL;DR');
    sb.writeln(tldr);
    sb.writeln();

    // (b) 5-Bullet Key Points
    sb.writeln('## 🔑 5 High-Yield Key Points');
    for (final kp in keyPoints) {
      final text = includeSources ? kp : kp.replaceAll(RegExp(r'\s*\[p\.\s*\d+\]'), '');
      sb.writeln('- $text');
    }
    sb.writeln();

    // (c) Detailed Section-by-Section Summary
    sb.writeln('## 📖 Section-by-Section Deep Dive');
    for (int i = 0; i < sections.length; i++) {
      final s = sections[i];
      final srcTag = (includeSources && s.sourcePage != null) ? ' [p. ${s.sourcePage}]' : '';
      final content = includeSources ? s.content : s.content.replaceAll(RegExp(r'\s*\[p\.\s*\d+\]'), '');
      sb.writeln('### ${i + 1}. ${s.title}$srcTag');
      sb.writeln(content);
      if (s.bulletPoints.isNotEmpty) {
        sb.writeln();
        for (final b in s.bulletPoints) {
          final bullet = includeSources ? b : b.replaceAll(RegExp(r'\s*\[p\.\s*\d+\]'), '');
          sb.writeln('- $bullet');
        }
      }
      sb.writeln();
    }

    // (d) Exam Cheat Sheet
    sb.writeln('## 📝 Exam Cheat Sheet');
    if (cheatSheet.definitions.isNotEmpty) {
      sb.writeln('### 📌 Core Definitions');
      for (final def in cheatSheet.definitions) {
        final src = (includeSources && def.page != null) ? ' [p. ${def.page}]' : '';
        sb.writeln('- **${def.term}**: ${def.definition}$src');
      }
      sb.writeln();
    }

    if (cheatSheet.formulasOrRules.isNotEmpty) {
      sb.writeln('### 💡 Essential Formulas & Rules');
      for (final rule in cheatSheet.formulasOrRules) {
        final src = (includeSources && rule.page != null) ? ' [p. ${rule.page}]' : '';
        sb.writeln('- **${rule.name}**: `${rule.formulaOrRule}` $src');
        if (rule.description != null && rule.description!.isNotEmpty) {
          sb.writeln('  *Context: ${rule.description}*');
        }
      }
      sb.writeln();
    }

    if (cheatSheet.highYieldTips.isNotEmpty) {
      sb.writeln('### 🎯 High-Yield Exam Takeaways');
      for (final tip in cheatSheet.highYieldTips) {
        sb.writeln('- $tip');
      }
      sb.writeln();
    }

    // (e) Glossary
    if (glossary.isNotEmpty) {
      sb.writeln('## 📚 Glossary of Terms');
      final sortedKeys = glossary.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (final key in sortedKeys) {
        sb.writeln('- **$key**: ${glossary[key]}');
      }
      sb.writeln();
    }

    // Mind Map Markdown
    if (mindMapMermaid.isNotEmpty) {
      sb.writeln('## 🗺️ Visual Mind Map (Mermaid)');
      sb.writeln('```mermaid');
      sb.writeln(mindMapMermaid);
      sb.writeln('```');
    }

    return sb.toString();
  }
}

/// A detailed subtopic or section summary with source page tracking.
class SectionSummary {
  final String title;
  final String? subtopic;
  final int? sourcePage;
  final String content;
  final List<String> bulletPoints;
  final List<String> keyTerms;

  const SectionSummary({
    required this.title,
    this.subtopic,
    this.sourcePage,
    required this.content,
    this.bulletPoints = const [],
    this.keyTerms = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtopic': subtopic,
      'sourcePage': sourcePage,
      'content': content,
      'bulletPoints': bulletPoints,
      'keyTerms': keyTerms,
    };
  }

  factory SectionSummary.fromMap(Map<String, dynamic> map) {
    return SectionSummary(
      title: (map['title'] ?? '') as String,
      subtopic: map['subtopic'] as String?,
      sourcePage: map['sourcePage'] as int?,
      content: (map['content'] ?? '') as String,
      bulletPoints: List<String>.from(map['bulletPoints'] ?? []),
      keyTerms: List<String>.from(map['keyTerms'] ?? []),
    );
  }
}

/// Exam cheat sheet containing definitions, formulas, key terms, must-remember list, and common mistakes.
class ExamCheatSheet {
  final List<DefinitionItem> definitions;
  final List<FormulaItem> formulasOrRules;
  final List<String> highYieldTips;
  final List<String> mustRemember;
  final List<String> commonMistakes;

  const ExamCheatSheet({
    this.definitions = const [],
    this.formulasOrRules = const [],
    this.highYieldTips = const [],
    this.mustRemember = const [],
    this.commonMistakes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'definitions': definitions.map((d) => d.toMap()).toList(),
      'formulasOrRules': formulasOrRules.map((f) => f.toMap()).toList(),
      'highYieldTips': highYieldTips,
      'mustRemember': mustRemember,
      'commonMistakes': commonMistakes,
    };
  }

  factory ExamCheatSheet.fromMap(Map<String, dynamic> map) {
    return ExamCheatSheet(
      definitions: (map['definitions'] as List<dynamic>? ?? [])
          .map((d) => DefinitionItem.fromMap(d as Map<String, dynamic>))
          .toList(),
      formulasOrRules: (map['formulasOrRules'] as List<dynamic>? ?? [])
          .map((f) => FormulaItem.fromMap(f as Map<String, dynamic>))
          .toList(),
      highYieldTips: List<String>.from(map['highYieldTips'] ?? []),
      mustRemember: List<String>.from(map['mustRemember'] ?? []),
      commonMistakes: List<String>.from(map['commonMistakes'] ?? []),
    );
  }
}

/// Represents one of the 5 questions a teacher would most likely ask on a topic.
class TeacherQuestion {
  final String question;
  final String answer;
  final String expectedKeyPoints;
  final int? sourcePage;

  const TeacherQuestion({
    required this.question,
    required this.answer,
    required this.expectedKeyPoints,
    this.sourcePage,
  });

  Map<String, dynamic> toMap() => {
    'question': question,
    'answer': answer,
    'expectedKeyPoints': expectedKeyPoints,
    'sourcePage': sourcePage,
  };

  factory TeacherQuestion.fromMap(Map<String, dynamic> map) => TeacherQuestion(
    question: (map['question'] ?? '') as String,
    answer: (map['answer'] ?? '') as String,
    expectedKeyPoints: (map['expectedKeyPoints'] ?? '') as String,
    sourcePage: map['sourcePage'] as int?,
  );
}

class DefinitionItem {
  final String term;
  final String definition;
  final int? page;

  const DefinitionItem({required this.term, required this.definition, this.page});

  Map<String, dynamic> toMap() => {'term': term, 'definition': definition, 'page': page};

  factory DefinitionItem.fromMap(Map<String, dynamic> map) => DefinitionItem(
        term: (map['term'] ?? '') as String,
        definition: (map['definition'] ?? '') as String,
        page: map['page'] as int?,
      );
}

class FormulaItem {
  final String name;
  final String formulaOrRule;
  final String? description;
  final int? page;

  const FormulaItem({
    required this.name,
    required this.formulaOrRule,
    this.description,
    this.page,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'formulaOrRule': formulaOrRule,
        'description': description,
        'page': page,
      };

  factory FormulaItem.fromMap(Map<String, dynamic> map) => FormulaItem(
        name: (map['name'] ?? '') as String,
        formulaOrRule: (map['formulaOrRule'] ?? '') as String,
        description: map['description'] as String?,
        page: map['page'] as int?,
      );
}

