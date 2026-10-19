import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
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

  // Flashcard Deck & Question Type Filter state
  bool _isFlashcardMode = false;
  String _questionTypeFilter = 'all'; // 'all', 'mcq', 'qa'

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

  /// Returns the questions filtered by the active topic dropdown and question type.
  List<Question> get _filteredQuestions {
    List<Question> list = _allQuestions;
    if (_selectedTopic != 'All Topics') {
      list = list
          .where((q) => q.topic.toLowerCase().trim() == _selectedTopic.toLowerCase().trim())
          .toList();
    }
    if (_questionTypeFilter == 'mcq') {
      list = list.where((q) => q.isMcq).toList();
    } else if (_questionTypeFilter == 'qa') {
      list = list.where((q) => !q.isMcq).toList();
    }
    return list;
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

      setState(() => _isProcessingPdf = true);

      // Show friendly botanical progress dialog
      if (!mounted) return;
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
                  const SizedBox(height: 18),
                  Text(
                    'Analyzing ${file.name}',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🍃 Extracting presentation slides & generating detailed practice questions for each topic...',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Process document into slide sections
      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: bytes,
        fileName: file.name,
        preferredTopic: _selectedTopic == 'All Topics' ? null : _selectedTopic,
      );

      // Generate detailed topic-by-topic summary and questions
      final aiResult = await NotesAiService.instance.processDocument(doc);

      // Save practice questions to Firestore (user-owned with global fallback)
      final authorId = FirestoreService.instance.currentUid ?? 'student_upload';
      if (aiResult.practiceQuestions.isNotEmpty) {
        await FirestoreService.instance.createQuestionsBatch(
          questions: aiResult.practiceQuestions
              .map((g) => (
                    topic: aiResult.topic,
                    question: g.question,
                    answer: g.answer,
                    subjectId: null,
                    unitId: null,
                    options: g.options,
                    correctOptionIndex: g.correctOptionIndex,
                    explanation: g.explanation,
                  ))
              .toList(),
          createdBy: authorId,
        );
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
                    '✨ Generated ${aiResult.practiceQuestions.length} practice questions from "${file.name}"!',
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
        await FirestoreService.instance.createQuestionsBatch(
          questions: questions
              .map((g) => (
                    topic: note.topic,
                    question: g.question,
                    answer: g.answer,
                    subjectId: null,
                    unitId: null,
                    options: g.options,
                    correctOptionIndex: g.correctOptionIndex,
                    explanation: g.explanation,
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
                        // Action 1: Make from Summarized Notes
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
                        // Action 2: Upload PDF / Notes
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
                  ],
                ),
              ),

              // Controls Bar: Mode Switcher (Deck vs Bank) & Question Type Filters
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
                        // Mode Switcher: Flashcards vs Question Bank
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
                                label: '🎴 Flashcard Deck',
                                isSelected: _isFlashcardMode,
                                onTap: () => setState(() => _isFlashcardMode = true),
                              ),
                              _buildModeButton(
                                label: '📋 Question Bank',
                                isSelected: !_isFlashcardMode,
                                onTap: () => setState(() => _isFlashcardMode = false),
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
                    // Type Filter Pills: All / MCQs Only / Conceptual Q&A
                    Row(
                      children: [
                        const Text(
                          'Type:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip(
                          label: 'All (${_allQuestions.length})',
                          isSelected: _questionTypeFilter == 'all',
                          onTap: () => setState(() => _questionTypeFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          label: 'MCQs (${_allQuestions.where((q) => q.isMcq).length})',
                          isSelected: _questionTypeFilter == 'mcq',
                          onTap: () => setState(() => _questionTypeFilter = 'mcq'),
                        ),
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          label: 'Conceptual (${_allQuestions.where((q) => !q.isMcq).length})',
                          isSelected: _questionTypeFilter == 'qa',
                          onTap: () => setState(() => _questionTypeFilter = 'qa'),
                        ),
                        const Spacer(),
                        if (_selectedTopic != 'All Topics')
                          InkWell(
                            onTap: () => setState(() => _selectedTopic = 'All Topics'),
                            child: const Row(
                              children: [
                                Icon(Icons.clear, size: 13, color: AppTheme.secondaryColor),
                                SizedBox(width: 3),
                                Text(
                                  'Clear Topic',
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
                        : _isFlashcardMode
                            ? _FlashcardDeckView(
                                questions: filtered,
                                topic: _selectedTopic,
                                onExitFlashcards: () => setState(() => _isFlashcardMode = false),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  return _PracticeQuestionItem(
                                    index: index + 1,
                                    question: filtered[index],
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
  int _score = 0;
  bool _isDeckFinished = false;

  void _selectOption(int optionIndex, Question question) {
    if (_userAnswers.containsKey(_currentIndex)) return; // Lock after answering

    setState(() {
      _userAnswers[_currentIndex] = optionIndex;
      if (optionIndex == question.correctOptionIndex) {
        _score++;
      }
    });
  }

  void _markQaUnderstood() {
    if (_understoodQa.contains(_currentIndex)) return;
    setState(() {
      _understoodQa.add(_currentIndex);
      _score++;
    });
  }

  void _nextCard() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _isDeckFinished = true);
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _restartDeck() {
    setState(() {
      _currentIndex = 0;
      _userAnswers.clear();
      _understoodQa.clear();
      _score = 0;
      _isDeckFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    // 1. Deck Completed Celebration Screen
    if (_isDeckFinished || _currentIndex >= questions.length) {
      final total = questions.length;
      final percentage = total > 0 ? ((_score / total) * 100).round() : 0;

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
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
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
                  decoration: BoxDecoration(
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
                const SizedBox(height: 28),
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
          constraints: const BoxConstraints(maxWidth: 640),
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
                    // Badge Row: Card Index, Topic Pill, Score Badge, Restart Button
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
                    const SizedBox(height: 18),

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
                                        : '✗ Incorrect. Correct: Option ${String.fromCharCode(65 + q.correctOptionIndex!)}',
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
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Non-MCQ Detailed Conceptual Question
                      _ConceptualFlashcardContent(
                        answer: q.answer,
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

/// Helper sub-widget for conceptual non-MCQ flashcards.
class _ConceptualFlashcardContent extends StatefulWidget {
  final String answer;
  final bool isUnderstood;
  final VoidCallback onMarkUnderstood;

  const _ConceptualFlashcardContent({
    required this.answer,
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
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.primaryColor),
                    SizedBox(width: 6),
                    Text(
                      '🌿 Verified Academic Answer:',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.answer,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
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
/// Supports interactive MCQ option selection directly in the list view!
class _PracticeQuestionItem extends StatefulWidget {
  final int index;
  final Question question;

  const _PracticeQuestionItem({
    required this.index,
    required this.question,
  });

  @override
  State<_PracticeQuestionItem> createState() => _PracticeQuestionItemState();
}

class _PracticeQuestionItemState extends State<_PracticeQuestionItem> {
  bool _isAnswerRevealed = false;
  int? _selectedOption;

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
            // Top Badge Row: Question Index, Type Badge, Topic Tag
            Row(
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
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                const Spacer(),
                const Icon(Icons.eco_outlined, size: 18, color: AppTheme.secondaryColor),
              ],
            ),
            const SizedBox(height: 14),

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
                        border: Border.all(color: borderColor, width: _selectedOption != null && (isCorrect || isSelected) ? 1.5 : 1.0),
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

              // Explanation Box if option selected or answered
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
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Non-MCQ: Traditional Tap to Reveal
              if (_isAnswerRevealed) ...[
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
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryColor),
                    icon: const Icon(Icons.visibility_off_outlined, size: 16),
                    label: const Text('Hide Answer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _isAnswerRevealed = false),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primaryColor),
                  label: const Text(
                    'Tap to reveal verified answer',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.secondaryColor, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                  ),
                  onPressed: () => setState(() => _isAnswerRevealed = true),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
