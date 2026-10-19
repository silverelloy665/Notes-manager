import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_processing_service.dart';

/// Represents a practice question generated from uploaded notes.
/// Supports both detailed conceptual Q&As and interactive 4-option MCQ flashcards.
class GeneratedPracticeQuestion {
  final String topic;
  final String question;
  final String answer;
  final String? sectionTitle;
  final List<String>? options; // 4 multiple choice options for MCQ flashcards
  final int? correctOptionIndex; // 0..3 index of the correct option
  final String? explanation; // Educational reasoning and explanation

  const GeneratedPracticeQuestion({
    required this.topic,
    required this.question,
    required this.answer,
    this.sectionTitle,
    this.options,
    this.correctOptionIndex,
    this.explanation,
  });

  bool get isMcq => options != null && options!.length >= 2 && correctOptionIndex != null;

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'question': question,
      'answer': answer,
      'sectionTitle': sectionTitle,
      if (options != null) 'options': options,
      if (correctOptionIndex != null) 'correctOptionIndex': correctOptionIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

/// Result returned from processing an uploaded file with AI.
class NoteAiProcessingResult {
  final String title;
  final String topic;
  final String summaryContent;
  final List<GeneratedPracticeQuestion> practiceQuestions;

  const NoteAiProcessingResult({
    required this.title,
    required this.topic,
    required this.summaryContent,
    required this.practiceQuestions,
  });
}

/// Service that automatically summarizes uploaded documents and generates
/// topic-based practice questions. Supports both Gemini Generative AI and an
/// intelligent offline fallback NLP synthesizer.
class NotesAiService {
  NotesAiService._();
  static final NotesAiService instance = NotesAiService._();

  // Can be configured at runtime or passed via --dart-define=GEMINI_API_KEY
  String? _geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  void setApiKey(String key) {
    _geminiApiKey = key.trim();
  }

  bool get hasApiKey => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

  /// High-level function: takes a [ProcessedDocument] and returns the complete
  /// generated summary notes and practice questions.
  Future<NoteAiProcessingResult> processDocument(ProcessedDocument doc) async {
    final title = doc.detectedTitle;
    final topic = doc.detectedTopic;
    final text = doc.fullText;

    // 1. Generate Summarized Notes
    final summary = await summarize(
      text: text,
      title: title,
      topic: topic,
      sections: doc.sections,
    );

    // 2. Generate Practice Questions from the notes & topics
    final questions = await generatePracticeQuestions(
      text: text,
      title: title,
      topic: topic,
      sections: doc.sections,
    );

    return NoteAiProcessingResult(
      title: title,
      topic: topic,
      summaryContent: summary,
      practiceQuestions: questions,
    );
  }

  /// Generates a structured study summary for the given text.
  Future<String> summarize({
    required String text,
    required String title,
    required String topic,
    List<DocumentSection> sections = const [],
  }) async {
    if (text.trim().isEmpty) {
      return 'No readable text was found in this document.';
    }

    if (hasApiKey) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _geminiApiKey!,
        );

        final prompt = '''
You are an expert academic tutor and professor.
Summarize the following study material on the topic "$topic" (Title: "$title").

Structure your response clearly with these sections:
## 📌 Executive Overview
(2-3 sentences explaining what this document is about and its core importance)

## 🎯 Core Concepts & Definitions
(Define 3-6 essential terms and concepts accurately with bullet points)

## 🔑 Key Takeaways & Summary Points
(5-8 clear, concise high-yield bullet points summarizing the core subject matter)

## 💡 Important Formulas / Rules / Insights
(Highlight key rules, steps, gotchas, or formulas students need for exams)

Text to summarize:
$text
''';

        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          return response.text!.trim();
        }
      } catch (_) {
        // Fall back to intelligent local summarizer
      }
    }

    return _generateLocalSummary(text: text, title: title, topic: topic, sections: sections);
  }

  /// Generates exam-oriented practice questions based on the notes content.
  /// Generates a rich, comprehensive bank of both detailed conceptual questions and 4-option MCQ flashcards.
  Future<List<GeneratedPracticeQuestion>> generatePracticeQuestions({
    required String text,
    required String title,
    required String topic,
    List<DocumentSection> sections = const [],
    int count = 15,
  }) async {
    if (text.trim().isEmpty) return [];

    if (hasApiKey) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _geminiApiKey!,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );

        final prompt = '''
You are an expert academic professor and test maker.
From the following study material on the topic "$topic" (Document Title: "$title"), generate a comprehensive bank of at least 15 to 20 high-quality practice questions covering EVERY section, slide, and concept.

Include a balanced mix of:
1. "Detailed Conceptual / Analytical Questions" testing core principles, trade-offs, and methodology.
2. "4-Option MCQ Flashcards" with 4 plausible options (A, B, C, D), the 0-based index of the correct option (0, 1, 2, or 3), and an educational explanation explaining why the answer is correct and why other options fail.

Return ONLY a valid JSON array of objects with these keys:
- "topic": "$topic"
- "sectionTitle": "Title of the slide or topic"
- "question": "Question text here..."
- "answer": "Detailed comprehensive answer text..."
- "options": ["Option A text", "Option B text", "Option C text", "Option D text"] (or null for non-MCQ questions)
- "correctOptionIndex": 0 (integer 0, 1, 2, or 3, or null for non-MCQ questions)
- "explanation": "Educational reasoning clarifying why the correct option is right..."

Notes text:
$text
''';

        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          final decoded = jsonDecode(response.text!.trim());
          if (decoded is List) {
            final list = <GeneratedPracticeQuestion>[];
            for (final item in decoded) {
              if (item is Map && item['question'] != null && item['answer'] != null) {
                List<String>? opts;
                if (item['options'] is List) {
                  opts = (item['options'] as List).map((e) => e.toString()).toList();
                }
                int? correctIdx;
                if (item['correctOptionIndex'] != null) {
                  correctIdx = int.tryParse(item['correctOptionIndex'].toString());
                }
                list.add(GeneratedPracticeQuestion(
                  topic: topic,
                  sectionTitle: item['sectionTitle']?.toString().trim(),
                  question: item['question'].toString().trim(),
                  answer: item['answer'].toString().trim(),
                  options: opts,
                  correctOptionIndex: correctIdx,
                  explanation: item['explanation']?.toString().trim(),
                ));
              }
            }
            if (list.isNotEmpty) return list;
          }
        }
      } catch (_) {
        // Fall back to local question generator
      }
    }

    return _generateLocalQuestions(
      text: text,
      title: title,
      topic: topic,
      sections: sections,
      count: count,
    );
  }

  /// High-yield local NLP summary generator that extracts core concepts,
  /// definitions, and structured takeaways for each topic without requiring external API calls.
  String _generateLocalSummary({
    required String text,
    required String title,
    required String topic,
    List<DocumentSection> sections = const [],
  }) {
    final sentences = _extractSentences(text);
    final definitions = _extractDefinitions(sentences);

    final sb = StringBuffer();

    // 1. Executive Header
    sb.writeln('## 📌 Executive Overview');
    if (sentences.isNotEmpty) {
      final overview = sentences.take(2).join(' ');
      sb.writeln('This study presentation covers the foundational and analytical principles of **$topic** (Document: "$title"). $overview');
    } else {
      sb.writeln('Comprehensive study summary and presentation notes for **$topic** ("$title").');
    }
    sb.writeln();

    // 2. Comprehensive Detailed Breakdown from EACH Topic / Slide
    if (sections.isNotEmpty) {
      sb.writeln('## 🍃 Detailed Breakdown by Topic');
      sb.writeln();

      for (int i = 0; i < sections.length; i++) {
        final sec = sections[i];
        final secTitle = sec.title.trim();
        if (secTitle.toLowerCase() == 'thank you') continue;

        sb.writeln('### 📖 ${i + 1}. $secTitle');
        final secSentences = _extractSentences(sec.content);

        // Core explanation for this topic
        if (secSentences.isNotEmpty) {
          sb.writeln('- **Core Focus:** ${secSentences.first}');
          if (secSentences.length > 1) {
            sb.writeln('- **Detailed Analysis:** ${secSentences.skip(1).take(2).join(' ')}');
          }
        } else {
          sb.writeln('- **Core Focus:** Detailed discussion and foundational principles of $secTitle.');
        }

        // Key Points / Numerical Data / Bullets in this section
        final lines = sec.content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final bullets = lines.where((l) => l.startsWith('•') || l.startsWith('-') || l.startsWith('*') || RegExp(r'^\d+\.').hasMatch(l)).toList();
        if (bullets.isNotEmpty) {
          sb.writeln('- **Key Takeaways:**');
          for (final b in bullets.take(4)) {
            sb.writeln('  • ${b.replaceAll(RegExp(r'^[•\-*\d.\s]+'), '')}');
          }
        } else {
          // If numbers, percentages, or items are present
          final metrics = RegExp(r'(\d+(?:\.\d+)?%|\b(?:item|point|step)\s*\d+\b)', caseSensitive: false)
              .allMatches(sec.content)
              .map((m) => m.group(0))
              .toList();
          if (metrics.isNotEmpty) {
            sb.writeln('- **Metrics & Findings:** Key indicators referenced: ${metrics.join(', ')}.');
          }
        }
        sb.writeln();
      }
    }

    // 3. Core Concepts & Definitions
    sb.writeln('## 🎯 Core Concepts & Definitions');
    if (definitions.isNotEmpty) {
      for (final def in definitions.take(6)) {
        sb.writeln('- **${def.term}**: ${def.explanation}');
      }
    } else if (sections.isNotEmpty) {
      for (final sec in sections.where((s) => s.title.toLowerCase() != 'thank you').take(5)) {
        sb.writeln('- **${sec.title}**: Key thematic area addressing essential principles in $topic.');
      }
    } else {
      sb.writeln('- **$title**: Primary study topic for $topic review.');
    }
    sb.writeln();

    // 4. Key Takeaways & Summary Points
    sb.writeln('## 🔑 Key Takeaways & Summary Points');
    if (sentences.isNotEmpty) {
      for (final s in sentences.take(5)) {
        sb.writeln('- $s');
      }
    } else {
      sb.writeln('- Comprehensive review points captured from $title.');
    }
    sb.writeln();

    // 5. Exam & Revision Tips
    sb.writeln('## 💡 Exam & Revision Tips');
    sb.writeln('- Review the detailed breakdown for each topic above, focusing on the problem statements, findings, and recommendations.');
    sb.writeln('- Practice the automatically generated questions in the **Practice** tab to test recall on every individual topic.');
    sb.writeln('- Pay special attention to quantitative findings and structural objectives.');

    return sb.toString();
  }

  /// High-yield local question generator that generates comprehensive questions for EACH topic/section,
  /// including properly phrased academic conceptual questions and interactive 4-option MCQ flashcards.
  List<GeneratedPracticeQuestion> _generateLocalQuestions({
    required String text,
    required String title,
    required String topic,
    List<DocumentSection> sections = const [],
    int count = 15,
  }) {
    final questions = <GeneratedPracticeQuestion>[];
    final sentences = _extractSentences(text);
    final definitions = _extractDefinitions(sentences);

    final effectiveSections = List<DocumentSection>.from(sections);
    if (effectiveSections.isEmpty) {
      effectiveSections.addAll(_extractSectionsFromMarkdownOrText(text));
    }

    int qCounter = 0;

    // 1. Generate Multiple Questions (Conceptual + MCQ Flashcards) for EACH Slide / Section
    if (effectiveSections.isNotEmpty) {
      for (final sec in effectiveSections) {
        final rawTitle = sec.title.trim();
        final lowerRaw = rawTitle.toLowerCase();
        if (lowerRaw == 'thank you' || lowerRaw == 'end of presentation' || rawTitle.isEmpty) {
          continue;
        }

        final cleanTitle = _sanitizeSectionTitle(rawTitle, topic);
        final secSentences = _extractSentences(sec.content);
        final contentSummary = secSentences.isNotEmpty
            ? secSentences.take(2).join(' ')
            : (sec.content.length > 140 ? '${sec.content.substring(0, 140)}...' : sec.content);

        final lowerTitle = cleanTitle.toLowerCase();
        final lowerContent = sec.content.toLowerCase();

        // Categorize section themes
        final isInstruction = lowerTitle.contains('assignment') ||
            lowerTitle.contains('instruction') ||
            lowerTitle.contains('activity') ||
            lowerTitle.contains('submission') ||
            lowerContent.contains('last date of submission') ||
            lowerContent.contains('select any topic');

        final isProblem = lowerTitle.contains('problem') || lowerTitle.contains('statement') || lowerContent.contains('problem statement');
        final isObjective = lowerTitle.contains('objective') || lowerTitle.contains('goal') || lowerTitle.contains('scope');
        final isMethod = lowerTitle.contains('method') ||
            lowerTitle.contains('advantage') ||
            lowerTitle.contains('disadvantage') ||
            lowerTitle.contains('proposed') ||
            lowerTitle.contains('implemented') ||
            lowerContent.contains('proposed/implemented');
        final isFindings = lowerTitle.contains('finding') ||
            lowerTitle.contains('analysis') ||
            lowerTitle.contains('result') ||
            lowerContent.contains('analysis of findings');
        final isConclusion = lowerTitle.contains('conclusion') || lowerTitle.contains('recommend') || lowerTitle.contains('future');
        final isReference = lowerTitle.contains('reference') || lowerTitle.contains('apa') || lowerTitle.contains('citation');

        if (isInstruction) {
          // --- Instruction / Assignment Guidelines Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'What are the core guidelines and submission criteria mandated in "$cleanTitle"?',
            answer: 'Key requirements in "$cleanTitle" ($topic):\n\n'
                '1. Domain Selection: Students must select an approved research topic within the $topic domain.\n'
                '2. Structured Methodology: Must formulate explicit problem statements and SMART objectives.\n'
                '3. Trade-off Analysis: Detailed comparative analysis of advantages and disadvantages of proposed/implemented methods.\n'
                '4. Academic Rigor: Empirical findings analysis and strict adherence to APA reference citation formats.\n'
                'Summary snippet: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'What is the required initial phase when undertaking an academic research assignment in $topic?',
            correctAnswer: 'Selecting an established topic within the $topic domain and formulating precise problem statements',
            distractors: [
              'Writing the final executive conclusion before reviewing existing literature',
              'Submitting unreferenced code without comparative trade-off analysis',
              'Omitting advantages and disadvantages of proposed solutions to save time',
            ],
            explanation: 'Academic research methodology requires starting with an established domain topic, followed by formulating testable problem statements and objectives prior to implementation.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'Which standardized citation guideline is required for documenting academic research references?',
            correctAnswer: 'APA format (or recognized peer-reviewed bibliographic citation standard)',
            distractors: [
              'Informal hyperlinks with no author names or publication dates',
              'Listing personal opinions as external academic evidence',
              'Omitting citations entirely to reduce report length',
            ],
            explanation: 'Standard citation styles such as APA ensure academic integrity by acknowledging original authors, publication years, and verifiable source publications.',
          ));
        } else if (isProblem) {
          // --- Problem Statements Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'Why is the formulation of precise problem statements critical in $topic research?',
            answer: 'In $topic, problem statements define the technical boundaries and research scope:\n\n'
                '1. Technical Focus: Identifies exact architectural or algorithmic limitations in current solutions.\n'
                '2. Measurable Benchmarks: Provides the baseline against which the proposed method is evaluated.\n'
                '3. Scope Management: Prevents scope creep by delineating what the project will and will not resolve.\n\n'
                'Context: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'What is the primary function of a problem statement in engineering and system design?',
            correctAnswer: 'To clearly identify a specific deficiency, performance bottleneck, or technical gap that requires resolution',
            distractors: [
              'To jump immediately into writing source code without architectural planning',
              'To list generic software frameworks without defining functional requirements',
              'To replace the need for empirical validation and stakeholder reviews',
            ],
            explanation: 'A rigorous problem statement articulates the specific challenge to be solved, justifying the project and guiding all subsequent design decisions.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'Which quality is essential when formulating academic problem statements?',
            correctAnswer: 'The problem statement must be specific, testable, and supported by empirical observations or literature',
            distractors: [
              'It should be deliberately ambiguous so goals can be altered arbitrarily',
              'It must assume that hardware upgrades will automatically resolve any defect',
              'It should avoid specifying any real-world operational constraints',
            ],
            explanation: 'Effective problem statements are testable and well-defined, providing clear criteria for validating whether a proposed solution succeeds.',
          ));
        } else if (isObjective) {
          // --- Objectives Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'How do project objectives correlate with problem statements in $cleanTitle?',
            answer: 'Objectives directly operationalize problem statements:\n\n'
                '1. Direct Mapping: Each formulated problem statement must have at least one corresponding objective.\n'
                '2. SMART Criteria: Objectives must be Specific, Measurable, Achievable, Relevant, and Time-bound.\n'
                '3. Evaluation Baseline: They define the verifiable deliverables and performance metrics for the study.\n\n'
                'Context: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'Under the SMART framework, what does "Measurable" signify for project objectives?',
            correctAnswer: 'The objective has concrete, quantifiable criteria and metrics to determine whether it has been met',
            distractors: [
              'The objective has no defined completion criteria or timelines',
              'The objective relies solely on subjective feelings rather than data',
              'The objective can never be evaluated during software testing',
            ],
            explanation: 'Measurable objectives establish quantifiable targets (e.g. latency, throughput, error rate reduction) that can be verified during testing.',
          ));
        } else if (isMethod) {
          // --- Methods & Advantages/Disadvantages Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'Why is it mandatory to evaluate both advantages and disadvantages of proposed versus implemented methods?',
            answer: 'In $topic, every architectural choice involves trade-offs:\n\n'
                '1. Objective Assessment: Demonstrates that the proposed solution delivers genuine benefits over existing baselines.\n'
                '2. Trade-Off Transparency: Identifies architectural costs (e.g. higher memory usage, algorithmic complexity, or setup overhead).\n'
                '3. Risk Mitigation: Understanding disadvantages enables developers to architect defensive fallbacks and optimizations.\n\n'
                'Context: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'When analyzing the trade-offs of an implemented software method, what does a "disadvantage" typically represent?',
            correctAnswer: 'A technical limitation such as computational complexity, resource consumption, or maintenance overhead',
            distractors: [
              'A complete failure that invalidates the entire project immediately',
              'A temporary compiler error that disappears without code changes',
              'An aesthetic preference in code formatting style',
            ],
            explanation: 'Disadvantages in software engineering usually involve real-world constraints such as algorithmic complexity, memory footprint, or operational dependencies.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'What is the primary advantage of comparing a proposed method against established baselines in literature?',
            correctAnswer: 'It provides empirical proof of superiority in key performance indicators such as speed, accuracy, or efficiency',
            distractors: [
              'It eliminates the need for unit testing and continuous integration',
              'It proves that the proposed solution is universally perfect in all contexts',
              'It guarantees zero software bugs across the application lifecycle',
            ],
            explanation: 'Baseline comparison objectively quantifies the degree of improvement the new method delivers over previous state-of-the-art implementations.',
          ));
        } else if (isFindings) {
          // --- Findings & Analysis Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'How does empirical data analysis support the credibility of research findings in $cleanTitle?',
            answer: 'Empirical data analysis provides reproducible scientific validation:\n\n'
                '1. Evidence-Based Validation: Replaces subjective intuition with measurable benchmarks, percentages, or error distributions.\n'
                '2. Trend Identification: Reveals how system performance behaves under varying workloads or edge conditions.\n'
                '3. Hypothesis Verification: Directly confirms whether the formulated objectives were achieved.\n\n'
                'Context: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'Why are quantitative findings preferred over qualitative claims in engineering reports?',
            correctAnswer: 'Quantitative data provides objective, reproducible benchmarks that can be independently verified and tested',
            distractors: [
              'Quantitative findings require no experimental setup or data collection',
              'Qualitative opinions are easier to automate in continuous testing pipelines',
              'Quantitative data hides system failures from peer reviewers',
            ],
            explanation: 'Quantitative metrics (e.g. response time, memory footprint, throughput) offer concrete, reproducible proof of system performance.',
          ));
        } else if (isConclusion) {
          // --- Conclusion & Recommendations Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'What constitutes an effective conclusion and set of recommendations in a $topic study?',
            answer: 'An effective conclusion synthesizes the entire research lifecycle:\n\n'
                '1. Synthesis of Outcomes: Summarizes the extent to which the problem statement was resolved.\n'
                '2. Practical Recommendations: Provides concrete guidance for software practitioners, architects, or researchers.\n'
                '3. Future Research Trajectories: Identifies unaddressed limitations and outlines future roadmap enhancements.\n\n'
                'Context: $contentSummary',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'What is the primary role of "Recommendations" in a technical research report?',
            correctAnswer: 'To translate analytical conclusions into actionable deployment steps and architectural improvements',
            distractors: [
              'To introduce completely unrelated topics that were never researched',
              'To restate raw code syntax without explaining practical relevance',
              'To invalidate previously established problem statements without reason',
            ],
            explanation: 'Recommendations convert research findings into actionable advice, guiding developers and decision-makers on practical implementation.',
          ));
        } else if (isReference) {
          // --- References & Bibliography Section ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'Why is rigorous bibliographic citation essential in academic and technical documentation?',
            answer: 'Proper academic citation serves multiple essential purposes:\n\n'
                '1. Scholarly Integrity: Credits original researchers and avoids intellectual plagiarism.\n'
                '2. Reproducibility: Allows peers to locate source literature, algorithms, and benchmark datasets.\n'
                '3. Scientific Context: Situates the current work within the broader historical body of knowledge.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'In academic research, which component is required when citing a peer-reviewed journal paper in APA format?',
            correctAnswer: 'Authors, publication year, article title, journal name, volume/issue numbers, and DOI or URL',
            distractors: [
              'Only a search engine query string without specific author details',
              'A personal blog comment without peer review or editorial oversight',
              'Just the first name of the primary author with no date',
            ],
            explanation: 'APA formatting requires complete bibliographic attribution: author names, publication year, article title, journal, volume, issue, page range, and DOI.',
          ));
        } else {
          // --- General Conceptual / Slide Topic ---
          questions.add(GeneratedPracticeQuestion(
            topic: topic,
            sectionTitle: cleanTitle,
            question: 'Explain the core principles and academic significance of "$cleanTitle" in $topic.',
            answer: 'Regarding "$cleanTitle" in $topic:\n\n'
                '1. Foundational Concept: $contentSummary\n'
                '2. Practical Application: This concept provides key building blocks for reliable system architecture, modular design, and robust implementation in $topic.\n'
                '3. Examination Key Point: Focus on how this principle interacts with overall system stability and performance.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'In the study of "$cleanTitle", which architectural principle is most essential for maintainability?',
            correctAnswer: 'High cohesion and loose coupling between system modules and components',
            distractors: [
              'Tightly intertwining presentation logic with database queries',
              'Storing all application state in unmanaged global variables',
              'Disabling compiler warnings and type checking to speed up builds',
            ],
            explanation: 'High cohesion ensures modules focus on a single responsibility, while loose coupling minimizes interdependencies, making systems easier to test and maintain.',
          ));

          questions.add(_createMcq(
            topic: topic,
            sectionTitle: cleanTitle,
            preferredIndex: (qCounter++) % 4,
            question: 'How does modular decomposition benefit complex systems in $cleanTitle?',
            correctAnswer: 'It isolates complexity, simplifies debugging, and enables concurrent development across engineering teams',
            distractors: [
              'It forces all code into a single monolithic script',
              'It eliminates the need for automated testing pipelines',
              'It removes the requirement for software documentation',
            ],
            explanation: 'Modular decomposition breaks large systems into manageable, independent units, improving code readability, reuse, and collaboration.',
          ));
        }
      }
    }

    // 2. Questions from Extracted Definitions
    for (final def in definitions) {
      questions.add(GeneratedPracticeQuestion(
        topic: topic,
        question: 'Define "${def.term}" and explain its operational role in $topic.',
        answer: '${def.term} is defined as:\n\n${def.explanation}\n\nKey context from notes: "${def.originalSentence}"',
      ));

      questions.add(_createMcq(
        topic: topic,
        preferredIndex: (qCounter++) % 4,
        question: 'Which of the following best defines "${def.term}" in $topic?',
        correctAnswer: def.explanation,
        distractors: [
          'An obsolete procedure with no practical relevance in modern computing',
          'A hardware component used exclusively for power regulation',
          'A proprietary protocol restricted to legacy mainframe systems',
        ],
        explanation: 'According to the study material: ${def.term} is defined as ${def.explanation}.',
      ));
    }

    // 3. Domain-Specific Academic Questions for Software Engineering & Common Topics
    if (topic.toLowerCase().contains('software')) {
      questions.add(_createMcq(
        topic: topic,
        preferredIndex: (qCounter++) % 4,
        question: 'What is the primary objective of Continuous Integration (CI) in modern Software Engineering?',
        correctAnswer: 'Automating build and test execution on code commits to detect integration bugs early',
        distractors: [
          'Eliminating the need for software version control systems',
          'Guaranteeing 100% bug-free releases without writing tests',
          'Replacing system architectural diagrams with informal chat logs',
        ],
        explanation: 'Continuous Integration regularly merges developer working copies to a shared mainline, automatically running automated tests to uncover regressions early.',
      ));

      questions.add(_createMcq(
        topic: topic,
        preferredIndex: (qCounter++) % 4,
        question: 'In Agile software development, what characterizes a "Sprint"?',
        correctAnswer: 'A time-boxed iteration (typically 1-4 weeks) focused on delivering a functional product increment',
        distractors: [
          'An indefinite design phase that locks requirements permanently',
          'A single day dedicated exclusively to refactoring database schemas',
          'A phase where stakeholder feedback is prohibited until project completion',
        ],
        explanation: 'Sprints are fixed time-boxed periods where development teams complete targeted user stories and deliver inspectable working software increments.',
      ));

      questions.add(_createMcq(
        topic: topic,
        preferredIndex: (qCounter++) % 4,
        question: 'What is the primary distinction between Verification and Validation in software quality assurance?',
        correctAnswer: 'Verification asks "Are we building the product right?", while Validation asks "Are we building the right product?"',
        distractors: [
          'Verification is performed by end users, while Validation is performed by compilers',
          'Verification only tests database performance, while Validation tests UI styling',
          'Verification and Validation are interchangeable terms with no technical distinction',
        ],
        explanation: 'Verification confirms software conforms to design specifications. Validation confirms the software satisfies the real-world operational needs of the customer.',
      ));

      questions.add(GeneratedPracticeQuestion(
        topic: topic,
        question: 'Explain the core phases of the Software Development Life Cycle (SDLC) and how Quality Assurance integrates into each phase.',
        answer: 'The SDLC consists of sequential and iterative stages:\n\n'
            '1. Requirements Analysis: Defining functional and non-functional specifications. QA validates requirements for clarity and testability.\n'
            '2. System Architecture & Design: Designing component diagrams, data flows, and interfaces. QA conducts architectural design reviews.\n'
            '3. Implementation (Coding): Translating designs into source code with unit tests.\n'
            '4. Testing & Verification: Executing integration, regression, security, and performance test suites.\n'
            '5. Deployment & Maintenance: Releasing via CI/CD pipelines, monitoring system metrics, and addressing patches.',
      ));
    }

    // 4. Ensure we have at least 15+ comprehensive questions
    if (questions.length < 15) {
      questions.add(_createMcq(
        topic: topic,
        preferredIndex: (qCounter++) % 4,
        question: 'What is the primary benefit of automated regression testing during software evolution?',
        correctAnswer: 'It ensures that recent code changes or optimizations do not break existing functional features',
        distractors: [
          'It replaces the need for code versioning and pull requests',
          'It rewrites the application architecture from scratch automatically',
          'It prevents developers from ever introducing runtime errors',
        ],
        explanation: 'Regression testing verifies that software changes, performance optimizations, or bug fixes have not compromised established system capabilities.',
      ));

      questions.add(GeneratedPracticeQuestion(
        topic: topic,
        question: 'How do empirical metrics and quantitative data validate engineering recommendations?',
        answer: 'Empirical metrics provide objective evidence. By measuring parameters such as latency, throughput, error rates, and resource utilization, engineers can substantiate conclusions and demonstrate measurable improvements over baseline methods.',
      ));
    }

    return questions;
  }

  /// Sanitizes section titles by removing broken OCR artifacts, trailing brackets, and slide numbers.
  String _sanitizeSectionTitle(String rawTitle, String defaultTopic) {
    var clean = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Fix broken OCR word separations
    clean = clean.replaceAll(RegExp(r'\bmethod\s+s\b', caseSensitive: false), 'methods')
                 .replaceAll(RegExp(r'\bSoft\s+ware\b', caseSensitive: false), 'Software');
    // Strip leading numbers or prefixes: "Slide 1: ", "1. ", "Section 2 - "
    clean = clean.replaceAll(RegExp(r'^(?:slide\s*\d+[:\-]?|section\s*\d+[:\-]?|\d+[\.\)\-]?)\s*', caseSensitive: false), '');
    // Strip trailing brackets or punctuation: e.g. "Assignment (" -> "Assignment"
    clean = clean.replaceAll(RegExp(r'[\(\[\{:\-\,\;]+$'), '').trim();

    // If title has unclosed parenthesis e.g. "Assignment (Research Activity"
    if (clean.contains('(') && !clean.contains(')')) {
      clean = '$clean)';
    }

    // Replace generic assignment titles with descriptive academic phrasing
    if (clean.toLowerCase() == 'assignment' || clean.toLowerCase() == 'assignment ()') {
      clean = 'Assignment Guidelines & Requirements';
    } else if (clean.toLowerCase().startsWith('assignment (') && clean.toLowerCase().endsWith(')')) {
      clean = 'Assignment: Research Activity Guidelines';
    }

    if (clean.isEmpty || clean.length < 3) {
      return '$defaultTopic: Overview & Methods';
    }

    return clean;
  }

  /// Helper to build a 4-option MCQ question with balanced distractor distribution.
  GeneratedPracticeQuestion _createMcq({
    required String topic,
    required String question,
    required String correctAnswer,
    required List<String> distractors,
    required String explanation,
    String? sectionTitle,
    int? preferredIndex,
  }) {
    final opts = <String>[...distractors.take(3)];
    final targetIndex = preferredIndex != null
        ? (preferredIndex % 4)
        : (question.length % 4);

    final finalOptions = <String>[];
    int distractorIdx = 0;
    for (int i = 0; i < 4; i++) {
      if (i == targetIndex) {
        finalOptions.add(correctAnswer);
      } else {
        if (distractorIdx < opts.length) {
          finalOptions.add(opts[distractorIdx]);
          distractorIdx++;
        } else {
          finalOptions.add('None of the above criteria');
        }
      }
    }

    return GeneratedPracticeQuestion(
      topic: topic,
      sectionTitle: sectionTitle,
      question: question,
      answer: correctAnswer,
      options: finalOptions,
      correctOptionIndex: targetIndex,
      explanation: explanation,
    );
  }

  /// Splits text into coherent sentences.
  List<String> _extractSentences(String text) {
    final cleaned = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final raw = cleaned.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])'));
    return raw
        .map((s) => s.trim())
        .where((s) => s.length >= 20 && !s.startsWith('===') && !s.startsWith('#'))
        .toList();
  }

  /// Finds definition-like statements (e.g. "X is defined as...", "X refers to...").
  List<({String term, String explanation, String originalSentence})> _extractDefinitions(List<String> sentences) {
    final results = <({String term, String explanation, String originalSentence})>[];
    final defRegex = RegExp(
      r'^(?:A |An |The )?([A-Z][a-zA-Z0-9\s_-]{2,30}?)\s+(?:is defined as|is a|is an|refers to|means|is the process of|represents|is used to)\s+(.+)$',
      caseSensitive: false,
    );

    for (final s in sentences) {
      final match = defRegex.firstMatch(s);
      if (match != null) {
        final term = match.group(1)?.trim() ?? '';
        final exp = match.group(2)?.trim() ?? '';
        if (term.isNotEmpty && exp.isNotEmpty && term.split(' ').length <= 4) {
          results.add((term: term, explanation: exp, originalSentence: s));
        }
      }
    }

    return results;
  }


  /// Reconstructs document sections from structured markdown headings (e.g. ### 📖 1. Introduction).
  List<DocumentSection> _extractSectionsFromMarkdownOrText(String text) {
    final sections = <DocumentSection>[];
    final lines = text.split('\n');
    String? currentTitle;
    final currentContent = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      final isHeading = trimmed.startsWith('### ') ||
          (trimmed.startsWith('## ') &&
              !trimmed.contains('Executive Overview') &&
              !trimmed.contains('Core Concepts') &&
              !trimmed.contains('Revision Tips') &&
              !trimmed.contains('Key Takeaways'));

      if (isHeading) {
        if (currentTitle != null && currentContent.isNotEmpty) {
          sections.add(DocumentSection(title: currentTitle, content: currentContent.toString().trim()));
          currentContent.clear();
        }
        currentTitle = trimmed.replaceAll(RegExp(r'^#+\s*(?:[📖🍃📌🎯🔑💡]\s*)?(?:\d+\.\s*)?'), '').trim();
      } else if (currentTitle != null) {
        currentContent.writeln(line);
      }
    }
    if (currentTitle != null && currentContent.isNotEmpty) {
      sections.add(DocumentSection(title: currentTitle, content: currentContent.toString().trim()));
    }
    return sections;
  }
}

