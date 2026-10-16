import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showNoteFormDialog({Note? existingNote}) {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');
    String selectedTopic = existingNote?.topic ?? AppConstants.academicTopics.first;
    bool isPinned = existingNote?.isPinned ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CustomDialog(
          title: existingNote == null ? 'Create New Note' : 'Edit Note',
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: titleController,
                    label: 'Note Title',
                    hintText: 'e.g. Process Scheduling Algorithms',
                    validator: (v) => Validators.validateRequired(v, 'Title'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Topic',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTopic,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: AppConstants.academicTopics
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedTopic = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: contentController,
                    label: 'Note Content',
                    hintText: 'Write your notes or summaries here...',
                    maxLines: 5,
                    validator: (v) => Validators.validateRequired(v, 'Content'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isPinned,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) => setDialogState(() => isPinned = val ?? false),
                      ),
                      const Text('Pin this note to the top'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          confirmText: existingNote == null ? 'Create Note' : 'Save Changes',
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
              } else {
                await FirestoreService.instance.updateNote(
                  userId: widget.currentUser.id,
                  noteId: existingNote.id,
                  title: titleController.text,
                  topic: selectedTopic,
                  content: contentController.text,
                  isPinned: isPinned,
                );
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(existingNote == null ? 'Note created!' : 'Note updated!'),
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
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sample Questions: $topic',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<({List<Question> questions, bool isFromCache})>(
                  stream: FirestoreService.instance.getQuestionsStream(topic: topic),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final questions = snapshot.data?.questions ?? [];
                    if (questions.isEmpty) {
                      return Center(
                        child: Text(
                          'No sample questions recorded for $topic yet.',
                          style: TextStyle(color: Colors.grey.shade600),
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
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
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search title or content...',
                  prefixIcon: const Icon(Icons.search, size: 20),
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
                children: ['All', ...AppConstants.academicTopics].map((topic) {
                  final isSelected = _selectedTopicFilter == topic;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(topic, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.note_alt_outlined,
                            title: _allNotes.isEmpty ? 'No Notes Added Yet' : 'No Matching Notes Found',
                            message: _allNotes.isEmpty
                                ? 'Create your first study note by tapping "New Note" below.'
                                : 'Try searching for different keywords or clearing your topic filters.',
                            actionText: _allNotes.isEmpty ? 'New Note' : 'Clear Filters',
                            onAction: _allNotes.isEmpty
                                ? () => _showNoteFormDialog()
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
                              onTap: () => _showNoteFormDialog(existingNote: note),
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
        onPressed: () => _showNoteFormDialog(),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onViewQuestions;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onViewQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: note.isPinned ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: note.isPinned
            ? const BorderSide(color: AppTheme.primaryColor, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.topic,
                      style: TextStyle(fontSize: 11, color: Colors.indigo.shade800, fontWeight: FontWeight.w600),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
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
                      const Icon(Icons.quiz_outlined, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Sample questions for ${note.topic}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q: ${widget.question.question}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_isRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  widget.question.answer,
                  style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.4),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _isRevealed = false),
                  child: const Text('Hide Answer', style: TextStyle(fontSize: 12)),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Tap to reveal answer', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _isRevealed = true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
