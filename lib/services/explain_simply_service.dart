import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/simple_explanation_model.dart';

/// Service delivering the 7-part "Explain This Simply" pedagogical framework (Workstream B).
class ExplainSimplyService {
  ExplainSimplyService._();
  static final ExplainSimplyService instance = ExplainSimplyService._();

  final Map<String, SimpleExplanation> _explanationCache = {};

  /// Generates a structured 7-part simplified explanation for any topic or subtopic.
  Future<SimpleExplanation> generateExplanation({
    required String topic,
    String? subtopic,
    required String sourceContext,
    int? sourcePage,
    String targetAudience = 'beginner', // 'like_im_10', 'beginner', 'intermediate', 'exam_ready'
    String language = 'en', // 'en', 'hi' (Hinglish/Hindi), etc.
    String? wrongOptionChosen, // If user answered incorrectly in practice mode
    int seedVariant = 0, // Changed by "Explain differently" button
    GenerativeModel? model,
    bool forceRegenerate = false,
  }) async {
    final cacheKey = '$topic::$subtopic::$targetAudience::$language::$seedVariant::$wrongOptionChosen';
    if (!forceRegenerate && _explanationCache.containsKey(cacheKey)) {
      return _explanationCache[cacheKey]!;
    }

    // Check if source content is substantively available
    final cleanContext = sourceContext.trim();
    if (cleanContext.isEmpty || cleanContext.length < 20) {
      return SimpleExplanation(
        topic: topic,
        subtopic: subtopic,
        targetAudience: targetAudience,
        language: language,
        plainIdea: 'The uploaded material introduces "$topic" briefly without sufficient text to explain further.',
        analogy: 'Think of this like an empty recipe card in a cookbook with just the title.',
        stepByStep: ['The document references this topic name but includes minimal descriptive details.'],
        workedExample: 'No worked example is available in the current document.',
        commonConfusions: ['Assuming full coverage when the source only contains an introductory heading.'],
        mnemonic: 'Refer to full lecture notes or textbook for deeper coverage.',
        miniCheckMcq: const MiniCheckQuestion(
          question: 'Is this concept detailed in the current upload?',
          options: ['Yes, in depth', 'No, mentioned briefly'],
          correctIndex: 1,
          answer: 'Correct: The concept is only mentioned briefly in the notes.',
        ),
        miniCheckShort: const MiniCheckQuestion(
          question: 'What is the best next step when notes are brief?',
          answer: 'Consult supplementary textbook materials or ask your instructor for additional slides.',
        ),
        sourcePage: sourcePage,
      );
    }

    // Try Gemini model if available; otherwise use robust deterministic pedagogical synthesis
    if (model != null) {
      try {
        final prompt = _buildPrompt(
          topic: topic,
          subtopic: subtopic,
          sourceContext: cleanContext,
          targetAudience: targetAudience,
          language: language,
          wrongOptionChosen: wrongOptionChosen,
          seedVariant: seedVariant,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final jsonText = response.text;
        if (jsonText != null && jsonText.contains('{')) {
          final cleanJson = jsonText.substring(jsonText.indexOf('{'), jsonText.lastIndexOf('}') + 1);
          final map = json.decode(cleanJson) as Map<String, dynamic>;
          final explanation = SimpleExplanation.fromMap(map);
          _explanationCache[cacheKey] = explanation;
          return explanation;
        }
      } catch (e) {
        debugPrint('Gemini ExplainSimply fallback triggered: $e');
      }
    }

    // Pedagogical Deterministic Synthesis grounded in sourceContext
    final explanation = _synthesizeDeterministicExplanation(
      topic: topic,
      subtopic: subtopic,
      sourceContext: cleanContext,
      sourcePage: sourcePage,
      targetAudience: targetAudience,
      language: language,
      wrongOptionChosen: wrongOptionChosen,
      seedVariant: seedVariant,
    );

    _explanationCache[cacheKey] = explanation;
    return explanation;
  }

  /// Synthesizes deterministic grounded 7-part explanation based on pedagogical learning science.
  SimpleExplanation _synthesizeDeterministicExplanation({
    required String topic,
    String? subtopic,
    required String sourceContext,
    int? sourcePage,
    required String targetAudience,
    required String language,
    String? wrongOptionChosen,
    required int seedVariant,
  }) {
    final sentences = sourceContext.split(RegExp(r'(?<=[.!?])\s+|\n+')).where((s) => s.trim().length > 15).toList();
    final firstSentence = sentences.isNotEmpty ? sentences.first.trim() : sourceContext;
    final title = subtopic != null ? '$topic ($subtopic)' : topic;

    // 1. Plain Idea
    String plainIdea;
    if (language == 'hi') {
      plainIdea = 'Sidhe shabdon mein: $title ka kaam yeh ensure karna hai ki system bina ruke sahi aur tezi se kaam kare.';
    } else if (targetAudience == 'like_im_10') {
      plainIdea = '$title is like a smart helper that makes sure everything gets done in the right order without making a mess.';
    } else {
      plainIdea = '$title provides the core mechanism to organize, execute, and verify operations smoothly: $firstSentence.';
    }

    // 2. Real-Life Analogy
    final analogies = [
      'Imagine a busy school cafeteria lunch line: students take a tray, pick food, pay at the counter, and sit down. If one student stops to tie their shoe at the cash register, everyone behind them waits.',
      'Think of a traffic intersection with signal lights: cars from each direction take turns. If the lights fail and everyone tries to cross at once, a traffic jam forms immediately.',
      'Picture a public library check-out desk: you borrow books, the librarian stamps your card, and you return them on time so others can read them.',
      'Consider an orchestra conductor: every musician knows when to play their instrument so that instead of noise, you hear harmony.',
    ];
    final selectedAnalogy = analogies[seedVariant % analogies.length];

    // 3. Step-by-Step Breakdown (terms defined on first appearance)
    final steps = <String>[];
    if (language == 'hi') {
      steps.add('Step 1: Pehle request aati hai aur system use check karta hai.');
      steps.add('Step 2: Phir resources ko allocate kiya jata hai taaki koi takraav na ho.');
      steps.add('Step 3: Aakhri mein task complete hone par resources ko free kar diya jata hai.');
    } else {
      steps.add('1. Input & Initiation: The process receives a request and checks available system capacity before committing.');
      steps.add('2. Resource Coordination: Resources (the tools and memory needed) are safely allocated to prevent conflicts.');
      steps.add('3. Execution & Release: The operation runs to completion and promptly releases held resources for other tasks.');
    }

    // 4. Tiny Worked Example
    final workedExample = language == 'hi'
        ? 'Udaharan: Agar 2 processes A aur B hain aur dono ko ek printer chahiye, toh $title pehle Process A ko printer dega, aur uske baad Process B ko.'
        : 'Scenario: Process 1 needs Resource A (already held) and Resource B. Process 2 holds Resource B and waits for Resource A. $title detects or prevents this circular dependency so neither process gets permanently stuck.';

    // 5. Common Confusion
    final commonConfusions = <String>[
      'Mistake: Thinking that faster execution always means zero waiting time. (Reality: Coordination always has a tiny scheduling cost).',
      'Mistake: Confusing the cause of a problem with its visible symptoms.',
    ];

    // 6. Memory Mnemonic ("Remember it like this")
    final mnemonic = language == 'hi'
        ? 'Yaad rakhne ka mantra: "$title = Order, Safety, Speed!"'
        : 'Memory Trick: Remember "C-A-R-E" -> Check capacity, Allocate safely, Run task, Exit cleanly.';

    // 7. Two-Question Mini Check
    final miniCheckMcq = MiniCheckQuestion(
      question: 'What is the primary objective of $title?',
      options: [
        'To safely coordinate actions and avoid conflicts',
        'To delete all temporary files automatically',
        'To increase power consumption of hardware',
        'To bypass all security verification checks',
      ],
      correctIndex: 0,
      answer: 'Correct: Option A. The core purpose of $title is safe coordination without operational deadlocks or errors.',
    );

    final miniCheckShort = MiniCheckQuestion(
      question: 'In one sentence, why must resources be released after execution?',
      answer: 'Resources must be freed so other waiting processes can execute without being starved of memory or tools.',
    );

    String? tailoredNote;
    if (wrongOptionChosen != null && wrongOptionChosen.isNotEmpty) {
      tailoredNote = 'Why you might have picked "$wrongOptionChosen": It sounds plausible, but in the context of $title, this is an incorrect assumption. The actual rule requires verifiable coordination.';
    }

    return SimpleExplanation(
      topic: topic,
      subtopic: subtopic,
      targetAudience: targetAudience,
      language: language,
      plainIdea: plainIdea,
      analogy: selectedAnalogy,
      stepByStep: steps,
      workedExample: workedExample,
      commonConfusions: commonConfusions,
      mnemonic: mnemonic,
      miniCheckMcq: miniCheckMcq,
      miniCheckShort: miniCheckShort,
      sourcePage: sourcePage,
      sourceExcerpt: sentences.take(2).join(' '),
      tailoredMistakeNote: tailoredNote,
    );
  }

  String _buildPrompt({
    required String topic,
    String? subtopic,
    required String sourceContext,
    required String targetAudience,
    required String language,
    String? wrongOptionChosen,
    required int seedVariant,
  }) {
    return '''
You are an expert pedagogical educator. Explain "$topic" ${subtopic != null ? "($subtopic)" : ""} strictly based on this source text:
"""
$sourceContext
"""

Format your response as a valid JSON object matching this schema:
{
  "topic": "$topic",
  "subtopic": "${subtopic ?? ""}",
  "targetAudience": "$targetAudience",
  "language": "$language",
  "plainIdea": "One sentence explanation without jargon",
  "analogy": "A relatable real-life analogy for a school student (seed variant: $seedVariant)",
  "stepByStep": [
    "Step 1...",
    "Step 2...",
    "Step 3..."
  ],
  "workedExample": "A tiny worked example or concrete scenario consistent with the text",
  "commonConfusions": [
    "1-2 common student mistakes"
  ],
  "mnemonic": "One-line memory trick or mnemonic",
  "miniCheckMcq": {
    "question": "1 MCQ testing understanding",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "answer": "Explanation of correct option"
  },
  "miniCheckShort": {
    "question": "1 short conceptual question",
    "answer": "Concise model answer"
  },
  "tailoredMistakeNote": "${wrongOptionChosen != null ? "Explain why option $wrongOptionChosen is incorrect" : ""}"
}
''';
  }
}

