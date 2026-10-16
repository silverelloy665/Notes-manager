import 'package:flutter/material.dart';
import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state.dart';
import 'student_grades_screen.dart';

/// Tab allowing students to join classrooms via a 6-character code and view enrolled classes.
class StudentClassroomsTab extends StatefulWidget {
  final User currentUser;

  const StudentClassroomsTab({super.key, required this.currentUser});

  @override
  State<StudentClassroomsTab> createState() => _StudentClassroomsTabState();
}

class _StudentClassroomsTabState extends State<StudentClassroomsTab> {
  List<Classroom> _classrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJoinedClassrooms();
  }

  Future<void> _loadJoinedClassrooms() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseService.instance.getStudentClassrooms(widget.currentUser.id!);
      if (mounted) {
        setState(() {
          _classrooms = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load classrooms: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showJoinClassDialog() {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return CustomDialog(
            title: 'Join Classroom',
            titleIcon: Icons.add_circle_outline,
            isLoading: dialogLoading,
            confirmLabel: 'Join',
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => dialogLoading = true);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final joined = await DatabaseService.instance.joinClassroom(
                  studentId: widget.currentUser.id!,
                  code: codeController.text.trim().toUpperCase(),
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Successfully joined "${joined.name}"!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
                _loadJoinedClassrooms();
              } on AppException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error joining class: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
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
                  const Text(
                    'Ask your teacher for the 6-character class join code (e.g. ABC123).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: codeController,
                    label: 'Class Code',
                    hint: 'e.g. ABC123',
                    textCapitalization: TextCapitalization.characters,
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                    validator: Validators.validateClassCode,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Join Class'),
        onPressed: _showJoinClassDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classrooms.isEmpty
              ? EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No Classrooms Joined',
                  message:
                      'You have not enrolled in any classroom yet. Tap "Join Class" below to enter a 6-character class code provided by your teacher.',
                  actionLabel: 'Join Classroom',
                  onAction: _showJoinClassDialog,
                )
              : RefreshIndicator(
                  onRefresh: _loadJoinedClassrooms,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacing),
                    itemCount: _classrooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final classroom = _classrooms[index];
                      return _StudentClassroomCard(
                        classroom: classroom,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentGradesScreen(
                                classroom: classroom,
                                student: widget.currentUser,
                              ),
                            ),
                          ).then((_) => _loadJoinedClassrooms());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _StudentClassroomCard extends StatelessWidget {
  final Classroom classroom;
  final VoidCallback onTap;

  const _StudentClassroomCard({
    required this.classroom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = classroom.studentOverallPercentage;
    final percentageDisplay = percentage != null
        ? '${percentage.toStringAsFixed(1)}%'
        : 'Not Graded';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.class_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classroom.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          classroom.subject,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Overall grade badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: percentage != null
                          ? (percentage >= 75
                              ? const Color(0xFFE8F5E9)
                              : percentage >= 50
                                  ? const Color(0xFFFFF8E1)
                                  : const Color(0xFFFFEBEE))
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: percentage != null
                            ? (percentage >= 75
                                ? const Color(0xFFA5D6A7)
                                : percentage >= 50
                                    ? const Color(0xFFFFE082)
                                    : const Color(0xFFFFCDD2))
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Overall Score',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        Text(
                          percentageDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: percentage != null
                                ? (percentage >= 75
                                    ? AppTheme.successColor
                                    : percentage >= 50
                                        ? AppTheme.warningColor
                                        : AppTheme.errorColor)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 8),

              // Teacher info + View Grades Prompt
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Instructor: ${classroom.teacherName ?? "Teacher"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Grades',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
