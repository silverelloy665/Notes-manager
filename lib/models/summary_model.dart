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
  final String mindMapMermaid; // Visual Mind Map in Mermaid syntax
  final String tone; // 'academic', 'simple'
  final String length; // 'concise', 'detailed', 'comprehensive'
  final String language; // 'en', etc.

  const MultiLevelSummary({
    required this.documentTitle,
    required this.topic,
    required this.tldr,
    required this.keyPoints,
    required this.sections,
    required this.cheatSheet,
    required this.glossary,
    required this.mindMapMermaid,
    this.tone = 'academic',
    this.length = 'detailed',
    this.language = 'en',
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
      'mindMapMermaid': mindMapMermaid,
      'tone': tone,
      'length': length,
      'language': language,
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
      mindMapMermaid: (map['mindMapMermaid'] ?? '') as String,
      tone: (map['tone'] ?? 'academic') as String,
      length: (map['length'] ?? 'detailed') as String,
      language: (map['language'] ?? 'en') as String,
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
      sb.writeln('- $kp');
    }
    sb.writeln();

    // (c) Detailed Section-by-Section Summary
    sb.writeln('## 📖 Section-by-Section Deep Dive');
    for (int i = 0; i < sections.length; i++) {
      final s = sections[i];
      final srcTag = (includeSources && s.sourcePage != null) ? ' [p. ${s.sourcePage}]' : '';
      sb.writeln('### ${i + 1}. ${s.title}$srcTag');
      sb.writeln(s.content);
      if (s.bulletPoints.isNotEmpty) {
        sb.writeln();
        for (final b in s.bulletPoints) {
          sb.writeln('- $b');
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

/// Exam cheat sheet containing definitions, formulas, and high-yield facts.
class ExamCheatSheet {
  final List<DefinitionItem> definitions;
  final List<FormulaItem> formulasOrRules;
  final List<String> highYieldTips;

  const ExamCheatSheet({
    this.definitions = const [],
    this.formulasOrRules = const [],
    this.highYieldTips = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'definitions': definitions.map((d) => d.toMap()).toList(),
      'formulasOrRules': formulasOrRules.map((f) => f.toMap()).toList(),
      'highYieldTips': highYieldTips,
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
    );
  }
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
