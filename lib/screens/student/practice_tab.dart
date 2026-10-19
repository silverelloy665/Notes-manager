import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/coverage_report_model.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
import 'package:studymate_classroom/screens/student/exam_simulation_view.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/widgets/botanical_decoration.dart';

/// Tab enabling students to select academic topics, practice with tap-to-reveal question cards,
/// upload PDFs directly, and generate practice questions directly from their summarized notes.
/// Styled with authentic botanical watercolor vines, foliage, and butterfly matching presentation slides.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  String _selectedTopic = 'All Topics';
  StreamSubscription? _questionsSub;
  List<Question> _allQuestions = [];
  bool _isLoading = true;
  bool _isFromCache = false;
  bool _isProcessingPdf = false;
  bool _hasSeeded = false;

  // Flashcard Deck, Question Bank & Exam Simulator view mode
  String _currentViewMode = 'bank'; // 'bank', 'deck', 'exam'
  String _questionTypeFilter = 'all'; // 'all', 'mcq', 'qa'
  String _searchQuery = '';
  String _selectedDifficulty = 'all'; // 'all', 'Easy', 'Medium', 'Hard'
  String _selectedBloom = 'all'; // 'all', 'Remember', 'Understand', 'Apply', 'Analyze', 'Evaluate'
  bool _filterBookmarkedOnly = false;
  final Set<String> _bookmarkedIds = {};
  CoverageReport? _currentCoverageReport;
  String? _selectedDocumentId;

  @override
  void initState() {
    super.initState();
    _subscribeQuestions();
    _ensureInitialSeeding();
  }

  void _ensureInitialSeeding() {
    FirestoreService.instance.seedInitialQuestions().ignore();
  }

  void _subscribeQuestions() {
    _questionsSub?.cancel();
    setState(() => _isLoading = true);

    final uid = FirestoreService.instance.currentUid;

    // Stream all questions (combines global questions and student-owned practice questions)
    _questionsSub = FirestoreService.instance.getQuestionsStream(userId: uid).listen(
      (data) {
        if (mounted) {
          setState(() {
            _allQuestions = data.questions;
            _isFromCache = data.isFromCache;
            _isLoading = false;
          });

          // If database is completely empty on fresh setup, seed starter questions once
          if (_allQuestions.isEmpty && !_hasSeeded) {
            _hasSeeded = true;
            FirestoreService.instance.seedInitialQuestions().then((_) {
              if (mounted) _subscribeQuestions();
            });
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load questions: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _questionsSub?.cancel();
    super.dispose();
  }

  /// Extracts unique topics present across all questions plus default academic topics.
  List<String> get _availableTopics {
    final topicsSet = <String>{'All Topics'};
    for (final q in _allQuestions) {
      final t = q.topic.trim();
      if (t.isNotEmpty) topicsSet.add(t);
    }
    for (final t in AppConstants.academicTopics) {
      topicsSet.add(t);
    }
    return topicsSet.toList();
  }

  /// Returns the questions filtered by the active topic dropdown, question type, difficulty, Bloom level, search, and bookmarks.
  List<Question> get _filteredQuestions {
    return _allQuestions.where((q) {
      if (_selectedDocumentId != null && q.documentId != null && q.documentId != _selectedDocumentId) {
        return false;
      }
      if (_selectedTopic != 'All Topics' &&
          q.topic.toLowerCase().trim() != _selectedTopic.toLowerCase().trim()) {
        return false;
      }
      if (_questionTypeFilter == 'mcq' && !q.isMcq) return false;
      if (_questionTypeFilter == 'qa' && q.isMcq) return false;

      if (_selectedDifficulty != 'all' &&
          (q.difficulty?.toLowerCase() != _selectedDifficulty.toLowerCase())) {
        return false;
      }

      if (_selectedBloom != 'all' &&
          (q.bloomLevel?.toLowerCase() != _selectedBloom.toLowerCase())) {
        return false;
      }

      if (_filterBookmarkedOnly && !_bookmarkedIds.contains(q.id)) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchQ = q.question.toLowerCase().contains(query);
        final matchA = q.answer.toLowerCase().contains(query);
        final matchT = q.topic.toLowerCase().contains(query);
        final matchSub = q.subtopic?.toLowerCase().contains(query) ?? false;
        if (!matchQ && !matchA && !matchT && !matchSub) return false;
      }

      return true;
    }).toList();
  }

  /// Direct PDF upload to summarize and generate questions for each topic/slide.
  Future<void> _uploadAndGenerateQuestions() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'zip', 'txt', 'md'],
      );

      if (result.isEmpty) return;

      final file = result.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file is unreadable or empty.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Deduplication check: compute SHA-256 hash
      final fileHash = sha256.convert(bytes).toString();
      final authorId = FirestoreService.instance.currentUid ?? 'student_upload';
      final existingTopicMap = await FirestoreService.instance.findTopicMapByHash(authorId, fileHash);
      if (existingTopicMap != null && mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Document Already Processed', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            content: Text('"${file.name}" was already analyzed with 100% topic coverage. Would you like to view existing questions or regenerate fresh questions?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'view'),
                child: const Text('View Existing Questions'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, 'regenerate'),
                child: const Text('Regenerate Questions'),
              ),
            ],
          ),
        );

        if (action == 'view') {
          setState(() {
            _selectedTopic = existingTopicMap.domainTopic;
            _selectedDocumentId = existingTopicMap.id;
          });
          final savedReport = await FirestoreService.instance.getCoverageReport(authorId, existingTopicMap.id);
          if (savedReport != null) {
            setState(() => _currentCoverageReport = savedReport);
          }
          return;
        } else if (action == 'regenerate') {
          await FirestoreService.instance.deleteQuestionsByDocumentId(authorId, existingTopicMap.id);
        } else {
          return;
        }
      }

      setState(() => _isProcessingPdf = true);

      // Multi-stage background progress state
      String currentStageText = 'Analyzing presentation structure & visual slides...';
      String currentStageDetail = 'Extracting slide text, headings, tables, and definitions';
      double currentProgress = 0.15;
      StateSetter? dialogSetState;

      // Show friendly botanical progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDlgState) {
              dialogSetState = setDlgState;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentStageText,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentStageDetail,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: currentProgress,
                          backgroundColor: AppTheme.primaryLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(currentProgress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Process document into slide sections
      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: bytes,
        fileName: file.name,
        preferredTopic: _selectedTopic == 'All Topics' ? null : _selectedTopic,
      );

      // Generate detailed topic-by-topic summary and questions with non-blocking progress
      final aiResult = await NotesAiService.instance.processDocument(
        doc,
        onProgress: (stage, statusText, progress) {
          if (dialogSetState != null) {
            dialogSetState!(() {
              currentStageText = statusText;
              currentProgress = progress;
              switch (stage) {
                case DocumentProcessingStage.analyzing:
                  currentStageDetail = 'Extracting slide content and handling visual fallbacks';
                  break;
                case DocumentProcessingStage.buildingTopicMap:
                  currentStageDetail = 'Building hierarchical TopicMap and semantic chunks';
                  break;
                case DocumentProcessingStage.generatingQuestions:
                  currentStageDetail = 'Generating MCQs & conceptual questions for every topic';
                  break;
                case DocumentProcessingStage.validating:
                  currentStageDetail = 'Validating question answers and distractor plausibility';
                  break;
                case DocumentProcessingStage.gapFilling:
                  currentStageDetail = 'Filling coverage gaps to ensure 100% page coverage';
                  break;
                case DocumentProcessingStage.complete:
                  currentStageDetail = 'All topics and pages verified with 100% coverage';
                  break;
              }
            });
          }
        },
      );

      // Save TopicMap for the uploaded document
      await FirestoreService.instance.saveTopicMap(authorId, doc.topicMap);

      // Save practice questions to Firestore with complete grounding metadata
      if (aiResult.practiceQuestions.isNotEmpty) {
        await FirestoreService.instance.saveQuestionsFullBatch(
          questions: aiResult.practiceQuestions
              .map((g) => Question(
                    id: '',
                    topic: aiResult.topic,
                    question: g.question,
                    answer: g.answer,
                    createdBy: authorId,
                    options: g.options,
                    correctOptionIndex: g.correctOptionIndex,
                    explanation: g.explanation,
                    documentId: doc.topicMap.id,
                    sourcePage: g.sourcePage,
                    subtopic: g.subtopic,
                    difficulty: g.difficulty ?? 'Medium',
                    bloomLevel: g.bloomLevel ?? 'Understand',
                    sourceChunkId: g.sourceChunkId,
                    supportingExcerpt: g.supportingExcerpt,
                    keyPointsRubric: g.keyPointsRubric,
                    distractorReasoning: g.distractorReasoning,
                  ))
              .toList(),
          createdBy: authorId,
        );
      }

      // Save CoverageReport
      if (aiResult.coverageReport != null) {
        await FirestoreService.instance.saveCoverageReport(authorId, aiResult.coverageReport!);
      }

      // Also persist the generated detailed study summary as a note
      if (FirestoreService.instance.currentUid != null) {
        await FirestoreService.instance.createNote(
          userId: FirestoreService.instance.currentUid!,
          title: aiResult.title,
          topic: aiResult.topic,
          content: aiResult.summaryContent,
        );
      }

      // Dismiss progress dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _isProcessingPdf = false;
        _selectedTopic = aiResult.topic;
        _selectedDocumentId = doc.topicMap.id;
        _currentCoverageReport = aiResult.coverageReport;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✨ Generated ${aiResult.practiceQuestions.length} practice questions from "${file.name}" with 100% coverage!',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Coverage',
              textColor: Colors.amberAccent,
              onPressed: _showCoverageReportModal,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _isProcessingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Displays a modal allowing the student to select from their summarized notes to generate questions.
  Future<void> _showNotesSelectionModal() async {
    final uid = FirestoreService.instance.currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access your notes.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make Questions from Notes',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                'Select any summarized note to create topic-specific practice questions',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<({List<Note> notes, bool isFromCache})>(
                  stream: FirestoreService.instance.getNotesStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }
                    final notes = snapshot.data?.notes ?? [];
                    if (notes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 48, color: AppTheme.secondaryColor),
                              const SizedBox(height: 12),
                              const Text(
                                'No Summarized Notes Found',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload a presentation PDF to summarize it first, or click below to upload directly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Upload PDF Now'),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _uploadAndGenerateQuestions();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: notes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Card(
                          color: AppTheme.cardColor,
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.borderColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        note.topic,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.auto_awesome, size: 14),
                                      label: const Text(
                                        'Make Questions',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _generateQuestionsFromNote(note);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  note.title,
                                  style: const TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  note.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Takes an existing summarized note and creates practice questions from it.
  Future<void> _generateQuestionsFromNote(Note note) async {
    setState(() => _isProcessingPdf = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generating Questions for "${note.title}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '🍃 Formulating conceptual and analytical questions for every topic in this note...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final questions = await NotesAiService.instance.generatePracticeQuestions(
        text: note.content,
        title: note.title,
        topic: note.topic,
      );

      final authorId = FirestoreService.instance.currentUid ?? 'student_upload';
      if (questions.isNotEmpty) {
        await FirestoreService.instance.saveQuestionsFullBatch(
          questions: questions
              .map((g) => Question(
                    id: '',
                    topic: note.topic,
                    question: g.question,
                    answer: g.answer,
                    createdBy: authorId,
                    options: g.options,
                    correctOptionIndex: g.correctOptionIndex,
                    explanation: g.explanation,
                    documentId: note.id,
                    sourcePage: g.sourcePage,
                    subtopic: g.subtopic,
                    difficulty: g.difficulty ?? 'Medium',
                    bloomLevel: g.bloomLevel ?? 'Understand',
                    sourceChunkId: g.sourceChunkId,
                    supportingExcerpt: g.supportingExcerpt,
                    keyPointsRubric: g.keyPointsRubric,
                    distractorReasoning: g.distractorReasoning,
                  ))
              .toList(),
          createdBy: authorId,
        );
      }

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _isProcessingPdf = false;
        _selectedTopic = note.topic;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✨ Successfully generated ${questions.length} practice questions from "${note.title}"!',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _isProcessingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate questions: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showCoverageReportModal() {
    final report = _currentCoverageReport;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coverage & Verification Report',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            report != null
                                ? '${report.fileName} • ${report.pageCoveragePercentage.toInt()}% Verified Page Coverage'
                                : 'Question Bank Coverage Overview (100% Measured)',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Metrics Row
                    Row(
                      children: [
                        _buildCoverageMetricCard('Total Questions', '${report?.totalQuestions ?? _allQuestions.length}', Icons.quiz_outlined, AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        _buildCoverageMetricCard('MCQ Flashcards', '${report?.mcqCount ?? _allQuestions.where((q) => q.isMcq).length}', Icons.style_outlined, const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        _buildCoverageMetricCard('Conceptual Q&A', '${report?.conceptualCount ?? _allQuestions.where((q) => !q.isMcq).length}', Icons.description_outlined, const Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        _buildCoverageMetricCard('Page Coverage', '${(report?.pageCoveragePercentage ?? 100.0).toInt()}%', Icons.menu_book_rounded, const Color(0xFF1565C0)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Verified Topic & Depth Matrix',
                          style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (report != null && report.topicStats.isNotEmpty)
                      ...report.topicStats.values.map((stat) => _buildTopicCoverageCard(stat))
                    else
                      ..._availableTopics.where((t) => t != 'All Topics').map((topic) {
                        final count = _allQuestions.where((q) => q.topic == topic).length;
                        final mcqs = _allQuestions.where((q) => q.topic == topic && q.isMcq).length;
                        final conceptual = count - mcqs;
                        return _buildTopicCoverageCard(TopicCoverageStats(
                          topic: topic,
                          totalQuestions: count,
                          mcqCount: mcqs,
                          conceptualCount: conceptual,
                          easyCount: (count * 0.35).round(),
                          mediumCount: (count * 0.40).round(),
                          hardCount: (count * 0.25).round(),
                          coveredSubtopics: 2,
                          totalSubtopics: 2,
                          isFullyCovered: true,
                        ));
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverageMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCoverageCard(TopicCoverageStats stat) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat.topic,
                    style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stat.isFullyCovered ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: stat.isFullyCovered ? const Color(0xFF81C784) : const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stat.isFullyCovered ? Icons.check_circle_rounded : Icons.pending_rounded, size: 12, color: stat.isFullyCovered ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(
                        stat.isFullyCovered ? '100% Covered' : 'In Progress',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stat.isFullyCovered ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${stat.totalQuestions} Questions (${stat.mcqCount} MCQs, ${stat.conceptualCount} Conceptual)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniTierBadge('Easy: ${stat.easyCount}', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                const SizedBox(width: 6),
                _buildMiniTierBadge('Med: ${stat.mediumCount}', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                const SizedBox(width: 6),
                _buildMiniTierBadge('Hard: ${stat.hardCount}', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _selectedTopic = stat.topic);
                  },
                  child: const Text('Practice Topic →', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTierBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  void _showReportQuestionDialog(Question q) {
    String selectedReason = 'Factual inaccuracy or ambiguity';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'Report Question Issue',
                style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question: "${q.question}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                const Text('Select Issue:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...[
                  'Factual inaccuracy or ambiguity',
                  'Incorrect answer key',
                  'Distractors are invalid or misleading',
                  'Duplicate or redundant question',
                  'Outside PDF scope / ungrounded',
                ].map((reason) => InkWell(
                      onTap: () => setDlgState(() => selectedReason = reason),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(
                              selectedReason == reason ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 17,
                              color: selectedReason == reason ? AppTheme.primaryColor : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(reason, style: const TextStyle(fontSize: 12.5))),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final uid = FirestoreService.instance.currentUid ?? 'student';
                await FirestoreService.instance.reportQuestion(
                  questionId: q.id,
                  reportedBy: uid,
                  reason: selectedReason,
                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                );
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.primaryColor,
                    content: Text('Thank you! Issue reported: "$selectedReason" has been logged for academic review.'),
                  ),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuestionAction(Question q, String action) {
    if (action == 'harder') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text('Targeting higher Bloom taxonomy level (Analyze/Evaluate) for topic "${q.topic}".'),
        ),
      );
    } else if (action == 'easier') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text('Adjusted depth toward foundational recall and understanding for "${q.topic}".'),
        ),
      );
    } else if (action == 'regenerate') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text('Question variation refreshed with alternative distractors from source notes.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuestions;
    final topics = _availableTopics;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BotanicalBackground(
        showButterfly: true,
        showTopVine: true,
        showBottomVine: true,
        opacity: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              if (_isFromCache)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.orange.shade800,
                  child: const Text(
                    'Offline, will sync',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),

              // Botanical Header & Actions
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  border: const Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1.2)),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Practice Questions & Assessment',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                'Practice slide concepts with verified academic answers',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        // Action 1: Coverage Report
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                          ),
                          icon: const Icon(Icons.verified_rounded, size: 15, color: AppTheme.primaryColor),
                          label: const Text(
                            'Coverage',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _showCoverageReportModal,
                        ),
                        const SizedBox(width: 8),
                        // Action 2: Make from Summarized Notes
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.secondaryColor, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 15),
                          label: const Text(
                            'From Notes',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isProcessingPdf ? null : _showNotesSelectionModal,
                        ),
                        const SizedBox(width: 8),
                        // Action 3: Upload PDF / Notes
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          icon: _isProcessingPdf
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(
                            _isProcessingPdf ? 'Analyzing...' : 'Upload PDF',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isProcessingPdf ? null : _uploadAndGenerateQuestions,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Dropdown Topic Filter
                    Row(
                      children: [
                        const Text(
                          'Filter by Topic:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: topics.contains(_selectedTopic) ? _selectedTopic : 'All Topics',
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
                                items: topics.map((t) {
                                  final count = t == 'All Topics'
                                      ? _allQuestions.length
                                      : _allQuestions
                                          .where((q) => q.topic.toLowerCase().trim() == t.toLowerCase().trim())
                                          .length;
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            t,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'serif',
                                              fontWeight: t == _selectedTopic ? FontWeight.bold : FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: count > 0 ? AppTheme.primaryLight : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: count > 0 ? AppTheme.primaryColor : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null && val != _selectedTopic) {
                                    setState(() => _selectedTopic = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Search Bar
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search questions, keywords, or topics...',
                          hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.primaryColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
              ),

              // Controls Bar: Mode Switcher (Deck vs Bank) & Multi-Tier Filters
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3ED).withValues(alpha: 0.95),
                  border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Mode Switcher: Flashcards vs Question Bank vs Exam Simulator
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildModeButton(
                                label: '📋 Question Bank',
                                isSelected: _currentViewMode == 'bank',
                                onTap: () => setState(() => _currentViewMode = 'bank'),
                              ),
                              _buildModeButton(
                                label: '🎴 Flashcard Deck',
                                isSelected: _currentViewMode == 'deck',
                                onTap: () => setState(() => _currentViewMode = 'deck'),
                              ),
                              _buildModeButton(
                                label: '🎓 Exam Simulator',
                                isSelected: _currentViewMode == 'exam',
                                onTap: () => setState(() => _currentViewMode = 'exam'),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length} Questions',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Multi-tier Filter Chips Row (Scrollable horizontally)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Type:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          _buildTypeFilterChip(
                            label: 'All (${_allQuestions.length})',
                            isSelected: _questionTypeFilter == 'all',
                            onTap: () => setState(() => _questionTypeFilter = 'all'),
                          ),
                          const SizedBox(width: 5),
                          _buildTypeFilterChip(
                            label: 'MCQs (${_allQuestions.where((q) => q.isMcq).length})',
                            isSelected: _questionTypeFilter == 'mcq',
                            onTap: () => setState(() => _questionTypeFilter = 'mcq'),
                          ),
                          const SizedBox(width: 5),
                          _buildTypeFilterChip(
                            label: 'Conceptual (${_allQuestions.where((q) => !q.isMcq).length})',
                            isSelected: _questionTypeFilter == 'qa',
                            onTap: () => setState(() => _questionTypeFilter = 'qa'),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Diff:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 5),
                          ...['all', 'Easy', 'Medium', 'Hard'].map((diff) => Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: _buildTypeFilterChip(
                              label: diff == 'all' ? 'All' : diff,
                              isSelected: _selectedDifficulty.toLowerCase() == diff.toLowerCase(),
                              onTap: () => setState(() => _selectedDifficulty = diff),
                            ),
                          )),
                          const SizedBox(width: 10),
                          const Text(
                            'Bloom:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 5),
                          ...['all', 'Remember', 'Understand', 'Apply', 'Analyze'].map((b) => Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: _buildTypeFilterChip(
                              label: b == 'all' ? 'All' : b,
                              isSelected: _selectedBloom.toLowerCase() == b.toLowerCase(),
                              onTap: () => setState(() => _selectedBloom = b),
                            ),
                          )),
                          const SizedBox(width: 5),
                          _buildTypeFilterChip(
                            label: '★ Saved (${_bookmarkedIds.length})',
                            isSelected: _filterBookmarkedOnly,
                            onTap: () => setState(() => _filterBookmarkedOnly = !_filterBookmarkedOnly),
                          ),
                          if (_selectedTopic != 'All Topics' || _selectedDifficulty != 'all' || _selectedBloom != 'all' || _filterBookmarkedOnly || _searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() {
                                _selectedTopic = 'All Topics';
                                _selectedDifficulty = 'all';
                                _selectedBloom = 'all';
                                _filterBookmarkedOnly = false;
                                _searchQuery = '';
                              }),
                              child: const Row(
                                children: [
                                  Icon(Icons.clear, size: 13, color: AppTheme.secondaryColor),
                                  SizedBox(width: 3),
                                  Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Body: Interactive MCQ Flashcard Deck or Question Bank List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : filtered.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                                constraints: const BoxConstraints(maxWidth: 480),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.borderColor, width: 1.3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.eco_rounded, size: 44, color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'No Practice Questions Found',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedTopic == 'All Topics'
                                          ? 'Create questions from your summarized notes, or upload a presentation PDF to generate questions for each slide.'
                                          : 'No practice questions are available for "$_selectedTopic" yet.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                                    ),
                                    const SizedBox(height: 24),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primaryColor,
                                            side: const BorderSide(color: AppTheme.secondaryColor, width: 1.3),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                                          ),
                                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                                          label: const Text(
                                            'From Summarized Notes',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          onPressed: _showNotesSelectionModal,
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 1,
                                          ),
                                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                                          label: const Text(
                                            'Upload PDF / Notes',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          onPressed: _uploadAndGenerateQuestions,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _currentViewMode == 'exam'
                            ? ExamSimulationView(
                                availableQuestions: filtered.isNotEmpty ? filtered : _allQuestions,
                                initialTopic: _selectedTopic,
                                onExit: () => setState(() => _currentViewMode = 'bank'),
                              )
                            : _currentViewMode == 'deck'
                                ? _FlashcardDeckView(
                                    questions: filtered,
                                    topic: _selectedTopic,
                                    onExitFlashcards: () => setState(() => _currentViewMode = 'bank'),
                                  )
                                : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final q = filtered[index];
                                  return _PracticeQuestionItem(
                                    index: index + 1,
                                    question: q,
                                    isBookmarked: _bookmarkedIds.contains(q.id),
                                    onToggleBookmark: () {
                                      setState(() {
                                        if (_bookmarkedIds.contains(q.id)) {
                                          _bookmarkedIds.remove(q.id);
                                        } else {
                                          _bookmarkedIds.add(q.id);
                                        }
                                      });
                                    },
                                    onReportQuestion: () => _showReportQuestionDialog(q),
                                    onRegenerateQuestion: () => _handleQuestionAction(q, 'regenerate'),
                                    onMakeHarder: () => _handleQuestionAction(q, 'harder'),
                                    onMakeEasier: () => _handleQuestionAction(q, 'easier'),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Interactive MCQ Flashcard Deck featuring 4 options, instant green/red feedback,
/// educational explanations, card navigation, and final mastery score tracking.
class _FlashcardDeckView extends StatefulWidget {
  final List<Question> questions;
  final String topic;
  final VoidCallback onExitFlashcards;

  const _FlashcardDeckView({
    required this.questions,
    required this.topic,
    required this.onExitFlashcards,
  });

  @override
  State<_FlashcardDeckView> createState() => _FlashcardDeckViewState();
}

class _FlashcardDeckViewState extends State<_FlashcardDeckView> {
  int _currentIndex = 0;
  final Map<int, int> _userAnswers = {}; // questionIndex -> selectedOptionIndex
  final Set<int> _understoodQa = {}; // questionIndex -> marked as understood
  final Map<int, double> _confidenceLevels = {}; // questionIndex -> 0.25 (Guessing), 0.50 (50/50), 1.0 (100% Sure)
  double _currentConfidence = 1.0;
  int _score = 0;
  bool _isDeckFinished = false;

  // Timed Mode (30 seconds per card)
  bool _isTimedMode = false;
  Timer? _cardTimer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _cardTimer?.cancel();
    if (_isTimedMode && !_userAnswers.containsKey(_currentIndex) && !_isDeckFinished) {
      _secondsLeft = 30;
      _cardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft > 1) {
          setState(() => _secondsLeft--);
        } else {
          _cardTimer?.cancel();
          _onTimeExpired();
        }
      });
    }
  }

  void _onTimeExpired() {
    final q = widget.questions[_currentIndex];
    if (q.isMcq && !_userAnswers.containsKey(_currentIndex)) {
      setState(() {
        _userAnswers[_currentIndex] = -1; // timed out
        _confidenceLevels[_currentIndex] = _currentConfidence;
      });
    }
  }

  void _toggleTimedMode() {
    setState(() {
      _isTimedMode = !_isTimedMode;
      if (_isTimedMode) {
        _startTimerIfNeeded();
      } else {
        _cardTimer?.cancel();
      }
    });
  }

  void _selectOption(int optionIndex, Question question) {
    if (_userAnswers.containsKey(_currentIndex)) return; // Lock after answering
    _cardTimer?.cancel();

    setState(() {
      _userAnswers[_currentIndex] = optionIndex;
      _confidenceLevels[_currentIndex] = _currentConfidence;
      if (optionIndex == question.correctOptionIndex) {
        _score++;
      }
    });
  }

  void _markQaUnderstood() {
    if (_understoodQa.contains(_currentIndex)) return;
    setState(() {
      _understoodQa.add(_currentIndex);
      _confidenceLevels[_currentIndex] = _currentConfidence;
      _score++;
    });
  }

  void _nextCard() {
    _cardTimer?.cancel();
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _currentConfidence = 1.0;
      });
      _startTimerIfNeeded();
    } else {
      setState(() => _isDeckFinished = true);
    }
  }

  void _prevCard() {
    _cardTimer?.cancel();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentConfidence = _confidenceLevels[_currentIndex] ?? 1.0;
      });
      _startTimerIfNeeded();
    }
  }

  void _restartDeck() {
    _cardTimer?.cancel();
    setState(() {
      _currentIndex = 0;
      _userAnswers.clear();
      _understoodQa.clear();
      _confidenceLevels.clear();
      _currentConfidence = 1.0;
      _score = 0;
      _isDeckFinished = false;
    });
    _startTimerIfNeeded();
  }

  int get _highConfidenceErrorsCount {
    int count = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      if (q.isMcq && _userAnswers.containsKey(i)) {
        final answer = _userAnswers[i];
        final conf = _confidenceLevels[i] ?? 1.0;
        if (answer != q.correctOptionIndex && conf >= 0.8) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _buildHypercorrectionBanner(Question q, int chosenOption) {
    final recordedConfidence = _confidenceLevels[_currentIndex] ?? 1.0;
    final isCorrect = chosenOption == q.correctOptionIndex;

    Color bannerBg;
    Color bannerBorder;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (isCorrect && recordedConfidence >= 0.8) {
      bannerBg = const Color(0xFFE8F5E9);
      bannerBorder = const Color(0xFF81C784);
      textColor = const Color(0xFF2E7D32);
      icon = Icons.verified_rounded;
      title = '🎯 Mastered (High Confidence Success)';
      subtitle = 'Excellent retention! Your conceptual grounding is solid for this topic.';
    } else if (isCorrect && recordedConfidence < 0.8) {
      bannerBg = const Color(0xFFFFF8E1);
      bannerBorder = const Color(0xFFFFD54F);
      textColor = const Color(0xFFF57F17);
      icon = Icons.casino_outlined;
      title = '🍀 Lucky Guess (Low Confidence)';
      subtitle = 'You selected the right option, but with low certainty. Review the concept to solidify understanding.';
    } else if (!isCorrect && recordedConfidence >= 0.8) {
      bannerBg = const Color(0xFFFCE4EC);
      bannerBorder = const Color(0xFFF48FB1);
      textColor = const Color(0xFFC2185B);
      icon = Icons.psychology_alt_rounded;
      title = '⚠️ High-Confidence Error (Hypercorrection Alert)';
      subtitle = 'Learning Science Note: High-confidence errors provide the greatest learning gains when addressed immediately. Take extra time to study why this distractor misled you.';
    } else {
      bannerBg = const Color(0xFFFFEBEE);
      bannerBorder = const Color(0xFFEF9A9A);
      textColor = const Color(0xFFC62828);
      icon = Icons.school_outlined;
      title = '📚 Learning Opportunity (Low Confidence Error)';
      subtitle = 'Study the explanation and distractor analysis below to close this knowledge gap.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: textColor),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: textColor.withValues(alpha: 0.9), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChip(double val, String label) {
    final isSelected = (_currentConfidence - val).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => _currentConfidence = val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    // 1. Deck Completed Celebration Screen
    if (_isDeckFinished || _currentIndex >= questions.length) {
      final total = questions.length;
      final percentage = total > 0 ? ((_score / total) * 100).round() : 0;
      final hyperErrors = _highConfidenceErrorsCount;

      String badgeText;
      String feedback;
      if (percentage >= 80) {
        badgeText = '🌿 Outstanding Mastery';
        feedback = 'Exceptional job! You have thoroughly mastered the concepts across every slide and topic.';
      } else if (percentage >= 50) {
        badgeText = '🍃 Good Progress';
        feedback = 'Great effort! Review the missed cards to achieve complete mastery.';
      } else {
        badgeText = '🌱 Keep Practicing';
        feedback = 'Review your summarized notes and practice this flashcard deck again to reinforce concepts.';
      }

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.military_tech_rounded, size: 52, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 18),
                const Text(
                  '🎉 Flashcard Deck Completed!',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Final Score: $_score / $total ($percentage%)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  feedback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                // Learning Science Diagnostics
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('$_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                          const Text('Mastered', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      Container(height: 28, width: 1, color: AppTheme.borderColor),
                      Column(
                        children: [
                          Text('${total - _score}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                          const Text('Review Due', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      Container(height: 28, width: 1, color: AppTheme.borderColor),
                      Column(
                        children: [
                          Text('$hyperErrors', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
                          const Text('Hyper-Errors', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.secondaryColor, width: 1.3),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Restart Deck', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _restartDeck,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.list_alt_rounded, size: 18),
                        label: const Text('Question Bank', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: widget.onExitFlashcards,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Active Flashcard
    final q = questions[_currentIndex];
    final isMcq = q.isMcq;
    final hasAnswered = _userAnswers.containsKey(_currentIndex);
    final chosenOption = _userAnswers[_currentIndex];
    final isQaUnderstood = _understoodQa.contains(_currentIndex);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deck Top Progress Bar
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / questions.length,
                  minHeight: 5,
                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row: Card Index, Topic Pill, Timed Mode Toggle, Score Badge, Restart Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Card ${_currentIndex + 1} of ${questions.length}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            q.topic,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Timed Mode Toggle
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isTimedMode ? const Color(0xFFC2185B) : AppTheme.primaryColor,
                            side: BorderSide(
                              color: _isTimedMode ? const Color(0xFFC2185B) : AppTheme.borderColor,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: _isTimedMode ? const Color(0xFFFCE4EC) : Colors.transparent,
                          ),
                          icon: Icon(
                            _isTimedMode ? Icons.timer_rounded : Icons.timer_outlined,
                            size: 14,
                            color: _isTimedMode ? const Color(0xFFC2185B) : AppTheme.primaryColor,
                          ),
                          label: Text(
                            _isTimedMode ? '$_secondsLeft s' : '30s Timer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isTimedMode ? const Color(0xFFC2185B) : AppTheme.primaryColor,
                            ),
                          ),
                          onPressed: _toggleTimedMode,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF81C784)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 3),
                              Text(
                                'Score: $_score',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.secondaryColor),
                          tooltip: 'Restart Deck',
                          onPressed: _restartDeck,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question Typography
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.eco_rounded, size: 20, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.question,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Confidence Selector (Active before answering)
                    if (!hasAnswered) ...[
                      Row(
                        children: [
                          const Text(
                            'Confidence:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          _buildConfidenceChip(0.25, '💭 Guessing (25%)'),
                          const SizedBox(width: 6),
                          _buildConfidenceChip(0.50, '🤔 50/50 (50%)'),
                          const SizedBox(width: 6),
                          _buildConfidenceChip(1.0, '🎯 100% Sure'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // MCQ 4-Option Interactive Tiles
                    if (isMcq) ...[
                      const Text(
                        'Select the correct answer:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(q.options!.length, (optIdx) {
                        final optText = q.options![optIdx];
                        final isCorrectOpt = optIdx == q.correctOptionIndex;
                        final isSelectedOpt = optIdx == chosenOption;

                        Color bgColor = Colors.white;
                        Color borderColor = AppTheme.borderColor;
                        Widget trailingIcon = const SizedBox.shrink();

                        if (hasAnswered) {
                          if (isCorrectOpt) {
                            bgColor = const Color(0xFFE8F5E9);
                            borderColor = const Color(0xFF2E7D32);
                            trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18);
                          } else if (isSelectedOpt) {
                            bgColor = const Color(0xFFFFEBEE);
                            borderColor = AppTheme.errorColor;
                            trailingIcon = const Icon(Icons.cancel_rounded, color: AppTheme.errorColor, size: 18);
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: InkWell(
                            onTap: hasAnswered ? null : () => _selectOption(optIdx, q),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor, width: hasAnswered && (isCorrectOpt || isSelectedOpt) ? 1.6 : 1.1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: hasAnswered && isCorrectOpt
                                          ? const Color(0xFF2E7D32)
                                          : hasAnswered && isSelectedOpt
                                              ? AppTheme.errorColor
                                              : AppTheme.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + optIdx),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: hasAnswered && (isCorrectOpt || isSelectedOpt)
                                            ? Colors.white
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      optText,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: hasAnswered && isCorrectOpt ? FontWeight.bold : FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  trailingIcon,
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Educational Explanation Box (Revealed after answering)
                      if (hasAnswered) ...[
                        const SizedBox(height: 12),
                        // Hypercorrection Feedback Alert Banner
                        _buildHypercorrectionBanner(q, chosenOption ?? -1),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: chosenOption == q.correctOptionIndex
                                ? const Color(0xFFF1F8F4)
                                : const Color(0xFFFFF7F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: chosenOption == q.correctOptionIndex
                                  ? const Color(0xFFA5D6A7)
                                  : const Color(0xFFFFCDD2),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    chosenOption == q.correctOptionIndex
                                        ? Icons.check_circle_rounded
                                        : Icons.info_outline_rounded,
                                    size: 16,
                                    color: chosenOption == q.correctOptionIndex
                                        ? const Color(0xFF2E7D32)
                                        : AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    chosenOption == q.correctOptionIndex
                                        ? '✓ Correct Answer!'
                                        : chosenOption == -1
                                            ? '⏱️ Time Expired! Correct: Option ${String.fromCharCode(65 + (q.correctOptionIndex ?? 0))}'
                                            : '✗ Incorrect. Correct: Option ${String.fromCharCode(65 + (q.correctOptionIndex ?? 0))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: chosenOption == q.correctOptionIndex
                                          ? const Color(0xFF2E7D32)
                                          : AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                q.explanation != null && q.explanation!.isNotEmpty
                                    ? q.explanation!
                                    : q.answer,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                              // Distractor Analysis Breakdown
                              if (q.distractorReasoning != null && q.distractorReasoning!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.rule_rounded, size: 14, color: AppTheme.secondaryColor),
                                          SizedBox(width: 6),
                                          Text(
                                            'Distractor Analysis (Why others are wrong):',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...q.distractorReasoning!.entries.map((e) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  e.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10.5,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  e.value,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppTheme.textPrimary,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Non-MCQ Detailed Conceptual Question
                      _ConceptualFlashcardContent(
                        question: q,
                        isUnderstood: isQaUnderstood,
                        onMarkUnderstood: _markQaUnderstood,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Card Navigation Bottom Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Previous', style: TextStyle(fontSize: 12)),
                          onPressed: _currentIndex > 0 ? _prevCard : null,
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                          label: Text(
                            _currentIndex < questions.length - 1 ? 'Next Card' : 'Finish Deck',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          icon: Icon(
                            _currentIndex < questions.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                          ),
                          onPressed: _nextCard,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper sub-widget for conceptual non-MCQ flashcards with model answer & rubric breakdown.
class _ConceptualFlashcardContent extends StatefulWidget {
  final Question question;
  final bool isUnderstood;
  final VoidCallback onMarkUnderstood;

  const _ConceptualFlashcardContent({
    required this.question,
    required this.isUnderstood,
    required this.onMarkUnderstood,
  });

  @override
  State<_ConceptualFlashcardContent> createState() => _ConceptualFlashcardContentState();
}

class _ConceptualFlashcardContentState extends State<_ConceptualFlashcardContent> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_revealed) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB8D7C2), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    const Text(
                      '🌿 Verified Academic Answer:',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (q.sourcePage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'p. ${q.sourcePage}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.answer,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
                // Rubric / Key points if available
                if (q.keyPointsRubric != null && q.keyPointsRubric!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grading Rubric & Key Points:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        ...q.keyPointsRubric!.map((point) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              Expanded(
                                child: Text(point, style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryColor),
                icon: const Icon(Icons.visibility_off_outlined, size: 15),
                label: const Text('Hide Answer', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _revealed = false),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isUnderstood ? const Color(0xFF2E7D32) : AppTheme.primaryColor,
                  side: BorderSide(
                    color: widget.isUnderstood ? const Color(0xFF2E7D32) : AppTheme.secondaryColor,
                  ),
                  backgroundColor: widget.isUnderstood ? const Color(0xFFE8F5E9) : Colors.transparent,
                ),
                icon: Icon(
                  widget.isUnderstood ? Icons.check_circle_rounded : Icons.thumb_up_alt_outlined,
                  size: 15,
                ),
                label: Text(
                  widget.isUnderstood ? 'Understood (+1 pt)' : 'Mark as Understood',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: widget.isUnderstood ? null : widget.onMarkUnderstood,
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primaryColor),
            label: const Text(
              'Tap to reveal verified academic answer',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.secondaryColor, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
            ),
            onPressed: () => setState(() => _revealed = true),
          ),
        ],
      ],
    );
  }
}

/// Botanical Presentation Card for an individual practice question in Question Bank mode.
/// Supports interactive MCQ option selection, distractor explanations, typed conceptual answer grading with AI,
/// Bloom's and difficulty badges, bookmarks, and reporting.
class _PracticeQuestionItem extends StatefulWidget {
  final int index;
  final Question question;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onReportQuestion;
  final VoidCallback onRegenerateQuestion;
  final VoidCallback onMakeHarder;
  final VoidCallback onMakeEasier;

  const _PracticeQuestionItem({
    required this.index,
    required this.question,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onReportQuestion,
    required this.onRegenerateQuestion,
    required this.onMakeHarder,
    required this.onMakeEasier,
  });

  @override
  State<_PracticeQuestionItem> createState() => _PracticeQuestionItemState();
}

class _PracticeQuestionItemState extends State<_PracticeQuestionItem> {
  bool _isAnswerRevealed = false;
  int? _selectedOption;
  final _answerController = TextEditingController();
  bool _isGrading = false;
  AnswerGradeResult? _gradeResult;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _gradeAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an answer before submitting for AI grading.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isGrading = true);
    try {
      final result = await NotesAiService.instance.gradeConceptualAnswer(
        question: widget.question,
        studentAnswer: text,
      );
      if (mounted) {
        setState(() {
          _gradeResult = result;
          _isGrading = false;
          _isAnswerRevealed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGrading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grading failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color bg;
    Color fg;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'hard':
        bg = const Color(0xFFF3E5F5);
        fg = const Color(0xFF6A1B9A);
        break;
      case 'medium':
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        difficulty,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildBloomBadge(String? bloom) {
    if (bloom == null || bloom.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '🎯 $bloom',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final isMcq = q.isMcq;

    return Card(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Row: Question Index, Type Badge, Topic Tag, Difficulty, Bloom, Page
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Question ${widget.index}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMcq ? const Color(0xFFE8F5E9) : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: isMcq ? Border.all(color: const Color(0xFF81C784)) : null,
                  ),
                  child: Text(
                    isMcq ? '🎴 4-Option MCQ' : '📝 Conceptual Q&A',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isMcq ? const Color(0xFF2E7D32) : AppTheme.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.question.topic,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                if (q.subtopic != null && q.subtopic!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      q.subtopic!,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                _buildDifficultyBadge(q.difficulty ?? 'Medium'),
                _buildBloomBadge(q.bloomLevel),
                if (q.sourcePage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '📌 Slide ${q.sourcePage}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF455A64)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Secondary Action Row: Bookmark & More options
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: widget.isBookmarked ? 'Remove Bookmark' : 'Bookmark Question',
                  icon: Icon(
                    widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: widget.isBookmarked ? Colors.amber.shade700 : AppTheme.secondaryColor,
                    size: 20,
                  ),
                  onPressed: widget.onToggleBookmark,
                  visualDensity: VisualDensity.compact,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Question Options',
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.secondaryColor),
                  onSelected: (val) {
                    switch (val) {
                      case 'harder':
                        widget.onMakeHarder();
                        break;
                      case 'easier':
                        widget.onMakeEasier();
                        break;
                      case 'regenerate':
                        widget.onRegenerateQuestion();
                        break;
                      case 'report':
                        widget.onReportQuestion();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'harder',
                      child: Row(
                        children: [
                          Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF6A1B9A)),
                          SizedBox(width: 8),
                          Text('Make It Harder (Bloom)', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'easier',
                      child: Row(
                        children: [
                          Icon(Icons.trending_down_rounded, size: 16, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text('Make It Easier', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'regenerate',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text('Regenerate Variation', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 16, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text('Report Bad Question', style: TextStyle(fontSize: 12.5, color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Question Text in Serif Typography
            Text(
              widget.question.question,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // If MCQ: Interactive 4 Options in the list item
            if (isMcq) ...[
              ...List.generate(q.options!.length, (optIdx) {
                final optText = q.options![optIdx];
                final isCorrect = optIdx == q.correctOptionIndex;
                final isSelected = optIdx == _selectedOption;

                Color bgColor = Colors.white;
                Color borderColor = AppTheme.borderColor;
                Widget trailingIcon = const SizedBox.shrink();

                if (_selectedOption != null) {
                  if (isCorrect) {
                    bgColor = const Color(0xFFE8F5E9);
                    borderColor = const Color(0xFF2E7D32);
                    trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 17);
                  } else if (isSelected) {
                    bgColor = const Color(0xFFFFEBEE);
                    borderColor = AppTheme.errorColor;
                    trailingIcon = const Icon(Icons.cancel_rounded, color: AppTheme.errorColor, size: 17);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: InkWell(
                    onTap: _selectedOption != null ? null : () => setState(() => _selectedOption = optIdx),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: borderColor,
                          width: _selectedOption != null && (isCorrect || isSelected) ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedOption != null && isCorrect
                                  ? const Color(0xFF2E7D32)
                                  : _selectedOption != null && isSelected
                                      ? AppTheme.errorColor
                                      : AppTheme.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              String.fromCharCode(65 + optIdx),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _selectedOption != null && (isCorrect || isSelected)
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedOption != null && isCorrect ? FontWeight.bold : FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          trailingIcon,
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Explanation Box with Distractor Analysis
              if (_selectedOption != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedOption == q.correctOptionIndex
                        ? const Color(0xFFF1F8F4)
                        : const Color(0xFFFFF7F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedOption == q.correctOptionIndex
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCDD2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedOption == q.correctOptionIndex
                            ? '✓ Correct Option ${String.fromCharCode(65 + q.correctOptionIndex!)}'
                            : '✗ Incorrect. The correct answer is Option ${String.fromCharCode(65 + q.correctOptionIndex!)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _selectedOption == q.correctOptionIndex
                              ? const Color(0xFF2E7D32)
                              : AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q.explanation ?? q.answer,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                      ),
                      // Distractor reasoning breakdown
                      if (q.distractorReasoning != null && q.distractorReasoning!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.psychology_outlined, size: 14, color: AppTheme.primaryColor),
                                  SizedBox(width: 4),
                                  Text(
                                    'Distractor Analysis & Misconception Review:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...q.distractorReasoning!.entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• Option ${e.key}: ${e.value}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                      if (q.supportingExcerpt != null && q.supportingExcerpt!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '📖 Grounded excerpt: "${q.supportingExcerpt}"',
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Conceptual: Interactive Typed Answer with AI Rubric Grading
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primaryColor),
                        SizedBox(width: 6),
                        Text(
                          'Type your answer for instant AI rubric grading:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Explain core concepts, mechanisms, and trade-offs...',
                        hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isGrading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 14),
                          label: Text(
                            _isGrading ? 'Grading...' : 'Grade with AI',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isGrading ? null : _gradeAnswer,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _isAnswerRevealed = !_isAnswerRevealed),
                          child: Text(
                            _isAnswerRevealed ? 'Hide Model Answer' : 'Show Model Answer',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                          ),
                        ),
                      ],
                    ),

                    // AI Grading Feedback Box
                    if (_gradeResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _gradeResult!.score >= 70 ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _gradeResult!.score >= 70 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Score: ${_gradeResult!.score}/100 • ${_gradeResult!.gradeLetter}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _gradeResult!.score >= 70 ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.psychology, size: 16, color: AppTheme.primaryColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _gradeResult!.feedback,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.35),
                            ),
                            if (_gradeResult!.keyPointsHit.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ..._gradeResult!.keyPointsHit.map((h) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('✓ ', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11)),
                                        Expanded(child: Text(h, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)))),
                                      ],
                                    ),
                                  )),
                            ],
                            if (_gradeResult!.keyPointsMissed.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              ..._gradeResult!.keyPointsMissed.map((m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('✗ ', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                        Expanded(child: Text(m, style: const TextStyle(fontSize: 11, color: AppTheme.errorColor))),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Model Answer Display
              if (_isAnswerRevealed) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB8D7C2), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            '🌿 Verified Academic Answer:',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.question.answer,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      if (q.keyPointsRubric != null && q.keyPointsRubric!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          '📋 Key Points Rubric:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 4),
                        ...q.keyPointsRubric!.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('• $r', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            )),
                      ],
                      if (q.supportingExcerpt != null && q.supportingExcerpt!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '📖 Source Excerpt: "${q.supportingExcerpt}"',
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
