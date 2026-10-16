import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/teacher/classroom_detail_screen.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Tab for teachers to manage created classrooms, copy join codes, and inspect enrolled students.
class TeacherClassroomsTab extends StatefulWidget {
  final User currentUser;

  const TeacherClassroomsTab({super.key, required this.currentUser});

  @override
  State<TeacherClassroomsTab> createState() => _TeacherClassroomsTabState();
}

class _TeacherClassroomsTabState extends State<TeacherClassroomsTab> {
  StreamSubscription? _classroomsSub;
  List<Classroom> _classrooms = [];
  bool _isLoading = true;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _subscribeClassrooms();
  }

  void _subscribeClassrooms() {
    _classroomsSub = FirestoreService.instance
        .getTeacherClassroomsStream(widget.currentUser.id)
        .listen(
      (data) {
        if (mounted) {
          setState(() {
            _classrooms = data.classrooms;
            _isFromCache = data.isFromCache;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load classrooms: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _classroomsSub?.cancel();
    super.dispose();
  }

  void _copyClassCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Classroom code "$code" copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCreateClassDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Create a Classroom',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Classroom Name',
                hintText: 'e.g. CS 301 - Operating Systems',
                validator: (v) => Validators.validateRequired(v, 'Classroom name'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: subjectController,
                label: 'Subject / Course',
                hintText: 'e.g. Computer Science & Engineering',
                validator: (v) => Validators.validateRequired(v, 'Subject'),
              ),
            ],
          ),
        ),
        confirmText: 'Create Class',
        onConfirm: () async {
          if (!formKey.currentState!.validate()) return;
          try {
            final created = await FirestoreService.instance.createClassroom(
              teacherId: widget.currentUser.id,
              teacherName: widget.currentUser.name,
              name: nameController.text,
              subject: subjectController.text,
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Classroom "${created.name}" created! Join code: ${created.code}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classrooms.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.class_outlined,
                            title: 'No Classrooms Created',
                            message: 'Create your first classroom by tapping "New Classroom" below to generate a join code for your students.',
                            actionText: 'New Classroom',
                            onAction: _showCreateClassDialog,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classrooms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final classroom = _classrooms[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ClassroomDetailScreen(
                                        classroom: classroom,
                                        teacher: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              classroom.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.indigo.shade100),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  classroom.code,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    color: AppTheme.primaryColor,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.copy, size: 14, color: AppTheme.primaryColor),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Copy join code',
                                                  onPressed: () => _copyClassCode(classroom.code),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        classroom.subject,
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        children: [
                                          const Icon(Icons.people_outline, size: 16, color: AppTheme.primaryColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${classroom.studentCount} Students Enrolled',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          const Text(
                                            'Manage Roster',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Classroom'),
        onPressed: _showCreateClassDialog,
      ),
    );
  }
}
