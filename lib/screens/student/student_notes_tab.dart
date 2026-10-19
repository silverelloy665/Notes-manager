import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/botanical_decoration.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Tab allowing students to manage personal notes, search, pin/unpin, and inspect sample questions per topic.
class StudentNotesTab extends StatefulWidget {
  final User currentUser;

  const StudentNotesTab({super.key, required this.currentUser});

  @override
  State<StudentNotesTab> createState() => _StudentNotesTabState();
}

class _StudentNotesTabState extends State<StudentNotesTab> {
  final _searchController = TextEditingController();
  StreamSubscription? _notesSub;
  List<Note> _allNotes = [];
  bool _isLoading = true;
  bool _isFromCache = false;
  String _selectedTopicFilter = 'All';

  @override
  void initState() {
    super.initState();
    _subscribeNotes();
  }

  void _subscribeNotes() {
    _notesSub = FirestoreService.instance.getNotesStream(widget.currentUser.id).listen(
      (data) {
        if (mounted) {
          setState(() {
            _allNotes = data.notes;
            _isFromCache = data.isFromCache;
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load notes: $err'), backgroundColor: AppTheme.errorColor),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _togglePin(Note note) async {
    try {
      await FirestoreService.instance.toggleNotePin(
        widget.currentUser.id,
        note.id,
        note.isPinned,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update pin: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.instance.deleteNote(widget.currentUser.id, note.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  void _showNoteFormDialog({Note? existingNote, bool autoPickFile = false}) {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');
    String selectedTopic = existingNote?.topic ?? AppConstants.academicTopics.first;
    bool isPinned = existingNote?.isPinned ?? false;
    final formKey = GlobalKey<FormState>();

    bool isAiProcessing = false;
    String? processingStatus;
    String? uploadedFileName;
    List<GeneratedPracticeQuestion> generatedQuestions = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickAndProcessFile() async {
            try {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'zip', 'txt', 'md'],
              );

              if (result.isEmpty) return;

              final file = result.first;
              final bytes = await file.readAsBytes();
              if (bytes.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File is empty or unreadable.'), backgroundColor: Colors.red),
                  );
                }
                return;
              }

              setDialogState(() {
                isAiProcessing = true;
                processingStatus = 'Analyzing ${file.name}...';
              });

              final doc = await DocumentProcessingService.instance.processBytes(
                bytes: bytes,
                fileName: file.name,
                preferredTopic: selectedTopic,
              );

              setDialogState(() {
                processingStatus = 'Extracting slide topics & generating practice questions...';
              });

              final aiResult = await NotesAiService.instance.processDocument(doc);

              setDialogState(() {
                uploadedFileName = file.name;
                titleController.text = aiResult.title;
                selectedTopic = aiResult.topic;
                contentController.text = aiResult.summaryContent;
                generatedQuestions = aiResult.practiceQuestions;
                isAiProcessing = false;
                processingStatus = null;
              });
            } catch (e) {
              setDialogState(() {
                isAiProcessing = false;
                processingStatus = null;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Processing failed: $e'), backgroundColor: Colors.red),
                );
              }
            }
          }

          if (autoPickFile && uploadedFileName == null && !isAiProcessing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              pickAndProcessFile();
            });
          }

          final availableDialogTopics = <String>{
            selectedTopic,
            ...AppConstants.academicTopics,
          }.toList();

          return CustomDialog(
            title: existingNote == null ? 'Create New Note' : 'Edit Note',
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Auto-Summarize & Quiz from PDF/ZIP Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Auto-Summarize & Practice from PDF / ZIP',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                  ),
                                  icon: isAiProcessing
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                                      : const Icon(Icons.upload_file, size: 16, color: AppTheme.primaryColor),
                                  label: Text(
                                    isAiProcessing ? 'Analyzing...' : 'Choose File',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: isAiProcessing ? null : pickAndProcessFile,
                                ),
                              ],
                            ),
                            if (processingStatus != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      processingStatus!,
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (uploadedFileName != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Summarized from: $uploadedFileName',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      CustomTextField(
                        controller: titleController,
                        label: 'Note Title',
                        hintText: 'e.g. Presentation on Study Topic',
                        validator: (v) => Validators.validateRequired(v, 'Title'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Topic',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTopic,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: availableDialogTopics
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedTopic = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: contentController,
                        label: 'Note Content (Detailed Summaries & Slide Breakdowns)',
                        hintText: 'Write or paste summaries here...',
                        maxLines: 6,
                        validator: (v) => Validators.validateRequired(v, 'Content'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: isPinned,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) => setDialogState(() => isPinned = val ?? false),
                          ),
                          const Text('Pin this note to the top', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ],
                      ),

                      // Practice Questions Preview
                      if (generatedQuestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '✨ ${generatedQuestions.length} Practice Questions Generated',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Will be saved to your Practice Question Bank under "$selectedTopic".',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              ...generatedQuestions.take(3).map((q) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                    Expanded(
                                      child: Text(
                                        q.question,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              if (generatedQuestions.length > 3)
                                Text(
                                  '+ ${generatedQuestions.length - 3} more questions for each topic',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.secondaryColor),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            confirmText: existingNote == null ? 'Create Note' : 'Save Changes',
            isLoading: isAiProcessing,
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (existingNote == null) {
                  await FirestoreService.instance.createNote(
                    userId: widget.currentUser.id,
                    title: titleController.text,
                    topic: selectedTopic,
                    content: contentController.text,
                    isPinned: isPinned,
                  );

                  // Batch save practice questions to Practice Question Bank
                  if (generatedQuestions.isNotEmpty) {
                    await FirestoreService.instance.createQuestionsBatch(
                      questions: generatedQuestions
                          .map((g) => (
                                topic: selectedTopic,
                                question: g.question,
                                answer: g.answer,
                                subjectId: null,
                                unitId: null,
                                options: g.options,
                                correctOptionIndex: g.correctOptionIndex,
                                explanation: g.explanation,
                              ))
                          .toList(),
                      createdBy: widget.currentUser.id,
                    );
                  }
                } else {
                  await FirestoreService.instance.updateNote(
                    userId: widget.currentUser.id,
                    noteId: existingNote.id,
                    title: titleController.text,
                    topic: selectedTopic,
                    content: contentController.text,
                    isPinned: isPinned,
                  );

                  // If user re-analyzed or generated new questions, save them too
                  if (generatedQuestions.isNotEmpty) {
                    await FirestoreService.instance.createQuestionsBatch(
                      questions: generatedQuestions
                          .map((g) => (
                                topic: selectedTopic,
                                question: g.question,
                                answer: g.answer,
                                subjectId: null,
                                unitId: null,
                                options: g.options,
                                correctOptionIndex: g.correctOptionIndex,
                                explanation: g.explanation,
                              ))
                          .toList(),
                      createdBy: widget.currentUser.id,
                    );
                  }
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  final msg = existingNote == null
                      ? (generatedQuestions.isNotEmpty
                          ? 'Note created and ${generatedQuestions.length} practice questions generated!'
                          : 'Note created successfully.')
                      : 'Note updated successfully.';
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }

  /// Displays the full detailed presentation note in a slide-style reader modal.
  void _showNoteDetailSheet(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Sheet Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
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
                          child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                'Topic: ${note.topic}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.secondaryColor),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showNoteFormDialog(existingNote: note);
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Practice Action Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EA),
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Practice questions generated for "${note.topic}"',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.quiz_outlined, size: 14),
                      label: const Text('Practice Topic', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSampleQuestions(note.topic);
                      },
                    ),
                  ],
                ),
              ),

              // Note Content Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _BotanicalNoteContentView(content: note.content),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSampleQuestions(String topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Practice Questions: $topic',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<({List<Question> questions, bool isFromCache})>(
                  stream: FirestoreService.instance.getQuestionsStream(topic: topic),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }
                    final questions = snapshot.data?.questions ?? [];
                    if (questions.isEmpty) {
                      return Center(
                        child: Text(
                          'No practice questions found for "$topic" yet.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final q = questions[index];
                        return _SampleQuestionCard(question: q);
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _allNotes.where((note) {
      final matchesTopic = _selectedTopicFilter == 'All' || note.topic == _selectedTopicFilter;
      final matchesQuery = query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
      return matchesTopic && matchesQuery;
    }).toList();

    final dynamicChipTopics = <String>{
      'All',
      ..._allNotes.map((n) => n.topic),
      ...AppConstants.academicTopics,
    }.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BotanicalBackground(
        showButterfly: false,
        showTopVine: true,
        showBottomVine: true,
        opacity: 0.85,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search study notes or slide breakdowns...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Topic Filter Chips
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: dynamicChipTopics.map((topic) {
                  final isSelected = _selectedTopicFilter == topic;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(topic, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryLight,
                      labelStyle: TextStyle(
                        fontFamily: 'serif',
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedTopicFilter = topic);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Notes List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : filtered.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.eco_outlined,
                            title: _allNotes.isEmpty ? 'No Notes Added Yet' : 'No Matching Notes Found',
                            message: _allNotes.isEmpty
                                ? 'Upload a presentation PDF or tap "New Note" to summarize your notes and generate practice questions.'
                                : 'Try searching for different keywords or clearing your topic filters.',
                            actionText: _allNotes.isEmpty ? 'Summarize PDF / ZIP' : 'Clear Filters',
                            onAction: _allNotes.isEmpty
                                ? () => _showNoteFormDialog(autoPickFile: true)
                                : () {
                                    _searchController.clear();
                                    setState(() => _selectedTopicFilter = 'All');
                                  },
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final note = filtered[index];
                            return _NoteCard(
                              note: note,
                              onTap: () => _showNoteDetailSheet(note),
                              onEdit: () => _showNoteFormDialog(existingNote: note),
                              onTogglePin: () => _togglePin(note),
                              onDelete: () => _deleteNote(note),
                              onViewQuestions: () => _showSampleQuestions(note.topic),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'student_notes_upload_ai',
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Summarize PDF/ZIP'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            onPressed: () => _showNoteFormDialog(autoPickFile: true),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'student_notes_new_note',
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            onPressed: () => _showNoteFormDialog(),
          ),
        ],
      ),
    );
  }
}

/// Formatted slide-style presentation view for note content.
class _BotanicalNoteContentView extends StatelessWidget {
  final String content;

  const _BotanicalNoteContentView({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else if (trimmed.startsWith('## ')) {
        // Main Section Header
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.eco_rounded, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trimmed.substring(3),
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        // Slide / Subsection Header Card
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              trimmed.substring(4),
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('• ') || trimmed.startsWith('* ')) {
        // Bullet Point
        final bulletText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 8),
                  child: Icon(Icons.circle, size: 6, color: AppTheme.secondaryColor),
                ),
                Expanded(
                  child: Text(
                    bulletText,
                    style: const TextStyle(fontSize: 13.5, color: AppTheme.textPrimary, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Regular Text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              trimmed,
              style: const TextStyle(fontSize: 13.5, color: AppTheme.textPrimary, height: 1.5),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}

/// Botanical card representing an individual note in the list.
class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onViewQuestions;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePin,
    required this.onDelete,
    required this.onViewQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: note.isPinned ? 2.5 : 1,
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: note.isPinned ? AppTheme.primaryColor : AppTheme.borderColor,
          width: note.isPinned ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isPinned)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 12, color: AppTheme.primaryColor),
                          SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.topic,
                      style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                      color: note.isPinned ? AppTheme.primaryColor : Colors.grey.shade500,
                    ),
                    tooltip: note.isPinned ? 'Unpin Note' : 'Pin Note',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onTogglePin,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                    tooltip: 'Edit Note',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: 'Delete Note',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note.title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onViewQuestions,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Practice questions for ${note.topic}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SampleQuestionCard extends StatefulWidget {
  final Question question;

  const _SampleQuestionCard({required this.question});

  @override
  State<_SampleQuestionCard> createState() => _SampleQuestionCardState();
}

class _SampleQuestionCardState extends State<_SampleQuestionCard> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q: ${widget.question.question}',
              style: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_isRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F9F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB8D7C2)),
                ),
                child: Text(
                  widget.question.answer,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4, fontFamily: 'serif'),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _isRevealed = false),
                  child: const Text('Hide Answer', style: TextStyle(fontSize: 12, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primaryColor),
                label: const Text('Tap to reveal answer', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.secondaryColor),
                ),
                onPressed: () => setState(() => _isRevealed = true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
