import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/screens/student/file_viewer_screen.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Detailed view of a unit showing Notes, Practicals, and Questions.
class UnitDetailScreen extends StatefulWidget {
  final String userId;
  final String subjectId;
  final String subjectName;
  final Unit unit;

  const UnitDetailScreen({
    super.key,
    required this.userId,
    required this.subjectId,
    required this.subjectName,
    required this.unit,
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isCompleted;
  String? _appDocDirPath;

  StreamSubscription? _resourcesSub;
  StreamSubscription? _questionsSub;
  List<ResourceItem> _allResources = [];
  List<Question> _unitQuestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isCompleted = widget.unit.completed;
    _initStorageAndStream();
  }

  Future<void> _initStorageAndStream() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() {
        _appDocDirPath = dir.path;
      });
    }

    _resourcesSub = FirestoreService.instance
        .getResourcesStream(widget.userId, widget.subjectId, widget.unit.id)
        .listen((data) {
      if (mounted) {
        setState(() {
          _allResources = data.resources;
          _isLoading = false;
        });
      }
    });

    _questionsSub = FirestoreService.instance
        .getUnitQuestionsStream(widget.userId, widget.subjectId, widget.unit.id)
        .listen((data) {
      if (mounted) {
        setState(() {
          _unitQuestions = data.questions;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resourcesSub?.cancel();
    _questionsSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleCompletion(bool val) async {
    setState(() => _isCompleted = val);
    try {
      await FirestoreService.instance.setUnitCompleted(
        widget.userId,
        widget.subjectId,
        widget.unit.id,
        val,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleted = !val);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getLocalFilePath(ResourceItem res) {
    if (_appDocDirPath == null) return '';
    return p.join(
      _appDocDirPath!,
      'library',
      widget.userId,
      widget.subjectName,
      'Unit ${widget.unit.number}',
      res.type == 'practical' ? 'practicals' : 'notes',
      res.name,
    );
  }

  Future<void> _openResource(ResourceItem res) async {
    final fullPath = _getLocalFilePath(res);
    final file = File(fullPath);

    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not on this device. Re-import the ZIP to restore it.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (res.isCodeOrText) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FileViewerScreen(
            resource: res,
            fullDiskPath: fullPath,
          ),
        ),
      );
    } else {
      try {
        final result = await OpenFilex.open(fullPath);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}. No compatible viewer app found.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open file: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _renameResource(ResourceItem res) {
    final nameController = TextEditingController(text: res.name);
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomDialog(
        title: 'Rename File',
        content: CustomTextField(
          controller: nameController,
          label: 'File Name',
          hintText: 'Enter new file name',
        ),
        confirmText: 'Rename',
        onConfirm: () async {
          final newName = nameController.text.trim();
          if (newName.isEmpty) return;
          try {
            await FirestoreService.instance.renameResource(
              widget.userId,
              widget.subjectId,
              widget.unit.id,
              res.id,
              newName,
            );
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File renamed successfully.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteResource(ResourceItem res) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomDialog(
        title: 'Delete File',
        content: Text('Are you sure you want to delete "${res.name}"? This removes it from Firestore and local storage.'),
        confirmText: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(dialogCtx).pop();
          try {
            await FirestoreService.instance.deleteResource(
              widget.userId,
              widget.subjectId,
              widget.unit.id,
              res.id,
              localFilePath: _getLocalFilePath(res),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File deleted.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _allResources.where((r) => r.isNote).toList();
    final practicals = _allResources.where((r) => r.isPractical).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Unit ${widget.unit.number}: ${widget.unit.title}'),
        actions: [
          Row(
            children: [
              Text(
                _isCompleted ? 'Completed' : 'Mark Done',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _isCompleted,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                onChanged: _toggleCompletion,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Notes (${notes.length})', icon: const Icon(Icons.description_outlined, size: 20)),
            Tab(text: 'Practicals (${practicals.length})', icon: const Icon(Icons.code_outlined, size: 20)),
            Tab(text: 'Questions (${_unitQuestions.length})', icon: const Icon(Icons.quiz_outlined, size: 20)),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildResourceList(notes, isPracticalTab: false),
                  _buildResourceList(practicals, isPracticalTab: true),
                  _buildQuestionsList(_unitQuestions),
                ],
              ),
      ),
    );
  }

  Widget _buildResourceList(List<ResourceItem> items, {required bool isPracticalTab}) {
    if (items.isEmpty) {
      return Center(
        child: EmptyState(
          icon: isPracticalTab ? Icons.code_off_outlined : Icons.menu_book_outlined,
          title: isPracticalTab ? 'No Practicals Found' : 'No Notes Found',
          message: isPracticalTab
              ? 'No laboratory experiments were detected in this unit.'
              : 'No lecture notes were detected in this unit.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final res = items[index];
        final sizeKb = (res.sizeBytes / 1024).toStringAsFixed(1);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPracticalTab
                  ? Colors.teal.shade50
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Icon(
                isPracticalTab ? Icons.code : Icons.description,
                color: isPracticalTab ? Colors.teal.shade700 : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              res.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${res.fileType.toUpperCase()} • $sizeKb KB',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'rename') _renameResource(res);
                if (val == 'delete') _deleteResource(res);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () => _openResource(res),
          ),
        );
      },
    );
  }

  Widget _buildQuestionsList(List<Question> questions) {
    if (questions.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'No Unit Questions',
          message: 'No questions.json was found in this unit folder. Practice questions added to questions.json will appear here.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _UnitQuestionCard(
          index: index + 1,
          question: questions[index],
        );
      },
    );
  }
}

class _UnitQuestionCard extends StatefulWidget {
  final int index;
  final Question question;

  const _UnitQuestionCard({
    required this.index,
    required this.question,
  });

  @override
  State<_UnitQuestionCard> createState() => _UnitQuestionCardState();
}

class _UnitQuestionCardState extends State<_UnitQuestionCard> {
  bool _isAnswerRevealed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.question,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isAnswerRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Verified Answer:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.question.answer,
                      style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: const Text('Hide Answer', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _isAnswerRevealed = false),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Tap to reveal answer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() => _isAnswerRevealed = true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
