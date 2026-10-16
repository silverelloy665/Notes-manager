import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/screens/student/unit_detail_screen.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Screen listing curriculum units within an imported subject.
class SubjectUnitsScreen extends StatefulWidget {
  final String userId;
  final Subject subject;

  const SubjectUnitsScreen({
    super.key,
    required this.userId,
    required this.subject,
  });

  @override
  State<SubjectUnitsScreen> createState() => _SubjectUnitsScreenState();
}

class _SubjectUnitsScreenState extends State<SubjectUnitsScreen> {
  StreamSubscription? _unitsSub;
  List<Unit> _units = [];
  bool _isLoading = true;
  bool _isFromCache = false;
  String? _appDocDirPath;

  @override
  void initState() {
    super.initState();
    _initDocDir();
    _subscribeUnits();
  }

  Future<void> _initDocDir() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() => _appDocDirPath = dir.path);
    }
  }

  void _subscribeUnits() {
    _unitsSub = FirestoreService.instance
        .getUnitsStream(widget.userId, widget.subject.id)
        .listen((data) {
      if (mounted) {
        setState(() {
          _units = data.units;
          _isFromCache = data.isFromCache;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _unitsSub?.cancel();
    super.dispose();
  }

  void _renameUnit(Unit unit) {
    final titleController = TextEditingController(text: unit.title);
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomDialog(
        title: 'Rename Unit',
        content: CustomTextField(
          controller: titleController,
          label: 'Unit Title',
          hintText: 'Enter unit title',
        ),
        confirmText: 'Save',
        onConfirm: () async {
          final newTitle = titleController.text.trim();
          if (newTitle.isEmpty) return;
          try {
            await FirestoreService.instance.renameUnit(
              widget.userId,
              widget.subject.id,
              unit.id,
              newTitle,
            );
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unit renamed successfully.')),
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

  void _deleteUnit(Unit unit) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomDialog(
        title: 'Delete Unit',
        content: Text('Are you sure you want to delete "Unit ${unit.number}: ${unit.title}" and all its contents?'),
        confirmText: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(dialogCtx).pop();
          try {
            final localPath = _appDocDirPath != null
                ? p.join(_appDocDirPath!, 'library', widget.userId, widget.subject.name, 'Unit ${unit.number}')
                : '';
            await FirestoreService.instance.deleteUnit(
              widget.userId,
              widget.subject.id,
              unit.id,
              localUnitPath: localPath,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unit deleted.')),
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
    final completedCount = _units.where((u) => u.completed).length;
    final progress = _units.isEmpty ? 0.0 : (completedCount / _units.length);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          if (_isFromCache)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Offline, will sync',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subject progress banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Curriculum Progress: ${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '$completedCount of ${_units.length} Units completed',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _units.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.layers_clear_outlined,
                            title: 'No Units Found',
                            message: 'No units were detected for this subject.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _units.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final unit = _units[index];
                            final qLabel = unit.questionsCount > 0 ? ' • ${unit.questionsCount} Qs' : '';
                            return Card(
                              child: ListTile(
                                leading: Checkbox(
                                  value: unit.completed,
                                  activeColor: Colors.green,
                                  onChanged: (val) {
                                    if (val != null) {
                                      FirestoreService.instance.setUnitCompleted(
                                        widget.userId,
                                        widget.subject.id,
                                        unit.id,
                                        val,
                                      );
                                    }
                                  },
                                ),
                                title: Text(
                                  'Unit ${unit.number}: ${unit.title}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration: unit.completed ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${unit.notesCount} Notes • ${unit.practicalsCount} Practicals$qLabel',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Rename Unit',
                                      onPressed: () => _renameUnit(unit),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete Unit',
                                      onPressed: () => _deleteUnit(unit),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UnitDetailScreen(
                                        userId: widget.userId,
                                        subjectId: widget.subject.id,
                                        subjectName: widget.subject.name,
                                        unit: unit,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
