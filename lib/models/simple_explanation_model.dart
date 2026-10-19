/// Data model for the 7-part "Explain This Simply" pedagogical framework (Workstream B).
class SimpleExplanation {
  final String topic;
  final String? subtopic;
  final String targetAudience; // 'like_im_10', 'beginner', 'intermediate', 'exam_ready'
  final String language; // 'en', 'hi' (Hinglish/Hindi), etc.
  final String plainIdea; // 1. The idea in one plain sentence (no jargon)
  final String analogy; // 2. Real-life analogy a school student would relate to
  final List<String> stepByStep; // 3. Step-by-step breakdown defining terms on first appearance
  final String workedExample; // 4. Tiny worked example (numbers, code, or scenario)
  final List<String> commonConfusions; // 5. Common confusion: 1-2 mistakes students make
  final String mnemonic; // 6. "Remember it like this": one-line memory trick
  final MiniCheckQuestion miniCheckMcq; // 7a. 1 MCQ with hidden answer
  final MiniCheckQuestion miniCheckShort; // 7b. 1 Short question with hidden answer
  final int? sourcePage;
  final String? sourceExcerpt;
  final String? tailoredMistakeNote; // Inline when answer was wrong

  const SimpleExplanation({
    required this.topic,
    this.subtopic,
    this.targetAudience = 'beginner',
    this.language = 'en',
    required this.plainIdea,
    required this.analogy,
    required this.stepByStep,
    required this.workedExample,
    required this.commonConfusions,
    required this.mnemonic,
    required this.miniCheckMcq,
    required this.miniCheckShort,
    this.sourcePage,
    this.sourceExcerpt,
    this.tailoredMistakeNote,
  });

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'subtopic': subtopic,
    'targetAudience': targetAudience,
    'language': language,
    'plainIdea': plainIdea,
    'analogy': analogy,
    'stepByStep': stepByStep,
    'workedExample': workedExample,
    'commonConfusions': commonConfusions,
    'mnemonic': mnemonic,
    'miniCheckMcq': miniCheckMcq.toMap(),
    'miniCheckShort': miniCheckShort.toMap(),
    'sourcePage': sourcePage,
    'sourceExcerpt': sourceExcerpt,
    'tailoredMistakeNote': tailoredMistakeNote,
  };

  factory SimpleExplanation.fromMap(Map<String, dynamic> map) => SimpleExplanation(
    topic: (map['topic'] ?? '') as String,
    subtopic: map['subtopic'] as String?,
    targetAudience: (map['targetAudience'] ?? 'beginner') as String,
    language: (map['language'] ?? 'en') as String,
    plainIdea: (map['plainIdea'] ?? '') as String,
    analogy: (map['analogy'] ?? '') as String,
    stepByStep: List<String>.from(map['stepByStep'] ?? []),
    workedExample: (map['workedExample'] ?? '') as String,
    commonConfusions: List<String>.from(map['commonConfusions'] ?? []),
    mnemonic: (map['mnemonic'] ?? '') as String,
    miniCheckMcq: MiniCheckQuestion.fromMap(map['miniCheckMcq'] as Map<String, dynamic>? ?? {}),
    miniCheckShort: MiniCheckQuestion.fromMap(map['miniCheckShort'] as Map<String, dynamic>? ?? {}),
    sourcePage: map['sourcePage'] as int?,
    sourceExcerpt: map['sourceExcerpt'] as String?,
    tailoredMistakeNote: map['tailoredMistakeNote'] as String?,
  );
}

/// Represents an interactive mini-check question with answer hidden behind a reveal tap.
class MiniCheckQuestion {
  final String question;
  final List<String>? options; // For MCQ (null for short question)
  final int? correctIndex;
  final String answer; // Revealable answer & explanation

  const MiniCheckQuestion({
    required this.question,
    this.options,
    this.correctIndex,
    required this.answer,
  });

  bool get isMcq => options != null && options!.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'answer': answer,
  };

  factory MiniCheckQuestion.fromMap(Map<String, dynamic> map) => MiniCheckQuestion(
    question: (map['question'] ?? '') as String,
    options: map['options'] != null ? List<String>.from(map['options']) : null,
    correctIndex: map['correctIndex'] as int?,
    answer: (map['answer'] ?? '') as String,
  );
}

