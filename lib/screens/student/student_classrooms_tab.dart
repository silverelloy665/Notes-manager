import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/student/student_grades_screen.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

/// Tab allowing students to join classrooms via 6-character codes and view enrolled courses.
class StudentClassroomsTab extends StatefulWidget {
  final User currentUser;

  const StudentClassroomsTab({super.key, required this.currentUser});

  @override
  State<StudentClassroomsTab> createState() => _StudentClassroomsTabState();
}

class _StudentClassroomsTabState extends State<StudentClassroomsTab> {
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
    _classroomsSub = FirestoreService.instance.getStudentClassroomsStream(widget.currentUser.id).listen(
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

  void _showJoinClassDialog() {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Join a Classroom',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the 6-character alphanumeric code provided by your instructor.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: codeController,
                label: 'Class Code',
                hintText: 'e.g. OS301A',
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                validator: Validators.validateClassCode,
              ),
            ],
          ),
        ),
        confirmText: 'Join Classroom',
        onConfirm: () async {
          if (!formKey.currentState!.validate()) return;
          try {
            final joined = await FirestoreService.instance.joinClassroom(
              studentId: widget.currentUser.id,
              code: codeController.text,
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully enrolled in "${joined.name}"!'),
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
                            icon: Icons.school_outlined,
                            title: 'No Classrooms Joined',
                            message: 'Join a classroom with the 6-character code given by your teacher to track assignments and grades.',
                            actionText: 'Join Classroom',
                            onAction: _showJoinClassDialog,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classrooms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final classroom = _classrooms[index];
                            return WatercolorBlobContainer(
                              variant: BlobVariant.sageSoft,
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.mintWash.withValues(alpha: 0.5),
                                  child: const Icon(Icons.school, color: AppTheme.inkForest),
                                ),
                                title: Text(
                                  classroom.name,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontCardo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5,
                                    color: AppTheme.inkForest,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Subject: ${classroom.subject}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate)),
                                    Text(
                                      'Instructor: ${classroom.teacherName}',
                                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkForest),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StudentGradesScreen(
                                        classroom: classroom,
                                        studentId: widget.currentUser.id,
                                        studentName: widget.currentUser.name,
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Join Classroom'),
        onPressed: _showJoinClassDialog,
      ),
    );
  }
}
