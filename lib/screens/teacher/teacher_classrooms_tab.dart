import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state.dart';
import 'classroom_detail_screen.dart';

/// Tab for teachers to manage created classrooms, copy join codes, and inspect enrolled students.
class TeacherClassroomsTab extends StatefulWidget {
  final User currentUser;

  const TeacherClassroomsTab({super.key, required this.currentUser});

  @override
  State<TeacherClassroomsTab> createState() => _TeacherClassroomsTabState();
}

class _TeacherClassroomsTabState extends State<TeacherClassroomsTab> {
  List<Classroom> _classrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherClassrooms();
  }

  Future<void> _loadTeacherClassrooms() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseService.instance.getTeacherClassrooms(widget.currentUser.id!);
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

  void _showCreateClassDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return CustomDialog(
            title: 'Create Classroom',
            titleIcon: Icons.add_home_work_outlined,
            isLoading: dialogLoading,
            confirmLabel: 'Create',
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => dialogLoading = true);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final created = await DatabaseService.instance.createClassroom(
                  teacherId: widget.currentUser.id!,
                  name: nameController.text.trim(),
                  subject: subjectController.text.trim(),
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Classroom "${created.name}" created! Join Code: ${created.code}'),
                      backgroundColor: AppTheme.successColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                _loadTeacherClassrooms();
              } on AppException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error creating class: $e'), backgroundColor: AppTheme.errorColor),
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
                    'Create a new academic batch. A unique 6-character code will be generated for students to join.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: nameController,
                    label: 'Classroom Name',
                    hint: 'e.g. CS 301 - Operating Systems Lab',
                    validator: (val) => Validators.validateRequired(val, 'Classroom name'),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: subjectController,
                    label: 'Subject / Course',
                    hint: 'e.g. Computer Science & Engineering',
                    validator: (val) => Validators.validateRequired(val, 'Subject'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _copyClassCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Join code "$code" copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
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
        label: const Text('New Classroom'),
        onPressed: _showCreateClassDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classrooms.isEmpty
              ? EmptyState(
                  icon: Icons.school_outlined,
                  title: 'No Classrooms Created',
                  message:
                      'Create your first classroom to invite students, administer practice tests, and track academic evaluation grades.',
                  actionLabel: 'Create Classroom',
                  onAction: _showCreateClassDialog,
                )
              : RefreshIndicator(
                  onRefresh: _loadTeacherClassrooms,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacing),
                    itemCount: _classrooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final classroom = _classrooms[index];
                      return _TeacherClassroomCard(
                        classroom: classroom,
                        onCopyCode: () => _copyClassCode(classroom.code),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClassroomDetailScreen(
                                classroom: classroom,
                                teacher: widget.currentUser,
                              ),
                            ),
                          ).then((_) => _loadTeacherClassrooms());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _TeacherClassroomCard extends StatelessWidget {
  final Classroom classroom;
  final VoidCallback onCopyCode;
  final VoidCallback onTap;

  const _TeacherClassroomCard({
    required this.classroom,
    required this.onCopyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.school, color: AppTheme.primaryColor, size: 24),
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
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Code Banner & Enrolled Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Code: ',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      classroom.code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onCopyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 12, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.people_outline, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${classroom.studentCount} ${classroom.studentCount == 1 ? "student" : "students"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tap to View Details
              const Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Students & Grades',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.primaryColor),
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
