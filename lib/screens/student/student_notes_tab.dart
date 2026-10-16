import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state.dart';

/// Tab allowing students to manage notes, search, pin/unpin, and view sample questions per topic.
class StudentNotesTab extends StatefulWidget {
  final User currentUser;

  const StudentNotesTab({super.key, required this.currentUser});

  @override
  State<StudentNotesTab> createState() => _StudentNotesTabState();
}

class _StudentNotesTabState extends State<StudentNotesTab> {
  final _searchController = TextEditingController();
  List<Note> _notes = [];
  bool _isLoading = true;
  String _selectedTopicFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await DatabaseService.instance.getNotes(
        widget.currentUser.id!,
        searchQuery: _searchController.text,
        topicFilter: _selectedTopicFilter == 'All' ? null : _selectedTopicFilter,
      );
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notes: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _togglePin(Note note) async {
    try {
      await DatabaseService.instance.togglePinNote(
        note.id!,
        widget.currentUser.id!,
        note.isPinned,
      );
      _loadNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update pin: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
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
        await DatabaseService.instance.deleteNote(note.id!, widget.currentUser.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadNotes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showNoteDialog({Note? noteToEdit}) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: noteToEdit?.title ?? '');
    final contentController = TextEditingController(text: noteToEdit?.content ?? '');
    String selectedTopic = noteToEdit?.topic ?? AppConstants.topics.first;
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return CustomDialog(
            title: noteToEdit == null ? 'Create New Note' : 'Edit Note',
            titleIcon: Icons.note_alt_outlined,
            isLoading: dialogLoading,
            confirmLabel: noteToEdit == null ? 'Create' : 'Save',
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => dialogLoading = true);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final now = DateTime.now().toIso8601String();
                if (noteToEdit == null) {
                  final newNote = Note(
                    userId: widget.currentUser.id!,
                    title: titleController.text.trim(),
                    topic: selectedTopic,
                    content: contentController.text.trim(),
                    isPinned: false,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await DatabaseService.instance.createNote(newNote);
                } else {
                  final updated = noteToEdit.copyWith(
                    title: titleController.text.trim(),
                    topic: selectedTopic,
                    content: contentController.text.trim(),
                    updatedAt: now,
                  );
                  await DatabaseService.instance.updateNote(updated);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadNotes();
              } on AppException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error saving note: $e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => dialogLoading = false);
                }
              }
            },
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextField(
                    controller: titleController,
                    label: 'Note Title',
                    hint: 'e.g. Process Scheduling Algorithms',
                    validator: (val) => Validators.validateRequired(val, 'Note title'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Topic',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTopic,
                    items: AppConstants.topics.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTopic = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: contentController,
                    label: 'Note Content',
                    hint: 'Write your detailed notes, key formulas or summaries here...',
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    validator: (val) => Validators.validateRequired(val, 'Note content'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSampleQuestionsForTopic(String topic) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return FutureBuilder<List<Question>>(
          future: DatabaseService.instance.getQuestions(topic: topic),
          builder: (context, snapshot) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.quiz_outlined, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sample Questions: $topic',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : (snapshot.data == null || snapshot.data!.isEmpty)
                              ? const EmptyState(
                                  icon: Icons.question_mark_rounded,
                                  title: 'No Questions Found',
                                  message: 'There are no practice questions seeded for this topic yet.',
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(AppTheme.spacing),
                                  itemCount: snapshot.data!.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final q = snapshot.data![index];
                                    return _QuestionRevealCard(question: q, index: index + 1);
                                  },
                                ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
        onPressed: () => _showNoteDialog(),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing, vertical: 12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadNotes(),
                  decoration: InputDecoration(
                    hintText: 'Search notes by title or content...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadNotes();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                // Horizontal topic chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: const Text('All Topics'),
                          selected: _selectedTopicFilter == 'All',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTopicFilter = 'All');
                              _loadNotes();
                            }
                          },
                        ),
                      ),
                      ...AppConstants.topics.map((topic) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(topic),
                            selected: _selectedTopicFilter == topic,
                            onSelected: (selected) {
                              setState(() => _selectedTopicFilter = selected ? topic : 'All');
                              _loadNotes();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),

          // Notes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? EmptyState(
                        icon: Icons.note_add_outlined,
                        title: _searchController.text.isNotEmpty
                            ? 'No Matching Notes'
                            : 'No Notes Created Yet',
                        message: _searchController.text.isNotEmpty
                            ? 'Try searching with different keywords or clearing filters.'
                            : 'Create organized study notes for your courses. Pin important notes to the top!',
                        actionLabel: _searchController.text.isNotEmpty ? 'Clear Search' : 'Create First Note',
                        onAction: () {
                          if (_searchController.text.isNotEmpty) {
                            _searchController.clear();
                            setState(() => _selectedTopicFilter = 'All');
                            _loadNotes();
                          } else {
                            _showNoteDialog();
                          }
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing, vertical: 12),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return _NoteCard(
                              note: note,
                              onTogglePin: () => _togglePin(note),
                              onEdit: () => _showNoteDialog(noteToEdit: note),
                              onDelete: () => _deleteNote(note),
                              onOpenQuestions: () => _showSampleQuestionsForTopic(note.topic),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTogglePin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenQuestions;

  const _NoteCard({
    required this.note,
    required this.onTogglePin,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Topic badge + Pin + More actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    note.topic,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (note.isPinned)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 13, color: Color(0xFF856404)),
                        SizedBox(width: 4),
                        Text(
                          'PINNED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF856404),
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: note.isPinned ? AppTheme.primaryColor : AppTheme.textMuted,
                    size: 20,
                  ),
                  tooltip: note.isPinned ? 'Unpin note' : 'Pin note to top',
                  onPressed: onTogglePin,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                    if (val == 'questions') onOpenQuestions();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Note'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'questions',
                      child: Row(
                        children: [
                          Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text('Sample Questions'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text('Delete Note', style: TextStyle(color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Note Title
            Text(
              note.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Note Content
            Text(
              note.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Footer: Sample Questions shortcut button
            InkWell(
              onTap: onOpenQuestions,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Sample questions for ${note.topic}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionRevealCard extends StatefulWidget {
  final Question question;
  final int index;

  const _QuestionRevealCard({required this.question, required this.index});

  @override
  State<_QuestionRevealCard> createState() => _QuestionRevealCardState();
}

class _QuestionRevealCardState extends State<_QuestionRevealCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_revealed)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Tap to reveal answer'),
                onPressed: () => setState(() => _revealed = true),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: AppTheme.successColor),
                        SizedBox(width: 6),
                        Text(
                          'Answer:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.question.answer,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.visibility_off_outlined, size: 14),
                  label: const Text('Hide answer', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _revealed = false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
