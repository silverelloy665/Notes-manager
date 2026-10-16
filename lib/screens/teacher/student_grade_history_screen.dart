import 'package:flutter/material.dart';
import '../../models/classroom_model.dart';
import '../../models/grade_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state.dart';

/// Screen allowing teachers to inspect a student's grade history and award new assessment grades.
class StudentGradeHistoryScreen extends StatefulWidget {
  final Classroom classroom;
  final StudentGradeSummary studentSummary;
  final User teacher;

  const StudentGradeHistoryScreen({
    super.key,
    required this.classroom,
    required this.studentSummary,
    required this.teacher,
  });

  @override
  State<StudentGradeHistoryScreen> createState() => _StudentGradeHistoryScreenState();
}

class _StudentGradeHistoryScreenState extends State<StudentGradeHistoryScreen> {
  List<Grade> _grades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseService.instance.getStudentGrades(
        widget.classroom.id!,
        widget.studentSummary.studentId,
      );
      if (mounted) {
        setState(() {
          _grades = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load grades: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  double? _calculateOverallPercentage() {
    if (_grades.isEmpty) return null;
    double totalObtained = 0.0;
    double totalMax = 0.0;
    for (final g in _grades) {
      totalObtained += g.marksObtained;
      totalMax += g.maxMarks;
    }
    if (totalMax <= 0) return null;
    return (totalObtained / totalMax) * 100.0;
  }

  void _showAddGradeDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final maxMarksController = TextEditingController(text: '100');
    final marksObtainedController = TextEditingController();
    final remarksController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return CustomDialog(
            title: 'Award Grade',
            titleIcon: Icons.add_chart_outlined,
            isLoading: dialogLoading,
            confirmLabel: 'Save Grade',
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => dialogLoading = true);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final maxMarks = double.parse(maxMarksController.text.trim());
                final marksObtained = double.parse(marksObtainedController.text.trim());

                await DatabaseService.instance.addGrade(
                  classroomId: widget.classroom.id!,
                  studentId: widget.studentSummary.studentId,
                  assessmentTitle: titleController.text.trim(),
                  maxMarks: maxMarks,
                  marksObtained: marksObtained,
                  remarks: remarksController.text.trim(),
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Grade successfully recorded!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
                _loadGrades();
              } on AppException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error adding grade: $e'), backgroundColor: AppTheme.errorColor),
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
                    label: 'Assessment Title',
                    hint: 'e.g. Midterm Exam, Quiz 1, Project Phase 1',
                    validator: (val) => Validators.validateRequired(val, 'Assessment title'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: maxMarksController,
                          label: 'Max Marks',
                          hint: '1 - 1000',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: Validators.validateMaxMarks,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          controller: marksObtainedController,
                          label: 'Marks Obtained',
                          hint: 'e.g. 85',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            final max = double.tryParse(maxMarksController.text.trim());
                            return Validators.validateMarksObtained(val, max);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: remarksController,
                    label: 'Remarks (Optional)',
                    hint: 'e.g. Excellent problem solving in dynamic programming',
                    maxLines: 2,
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
    final overall = _calculateOverallPercentage();
    final overallDisplay = overall != null ? '${overall.toStringAsFixed(1)}%' : 'Not Graded';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentSummary.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Grade'),
        onPressed: _showAddGradeDialog,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadGrades,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacing),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Student Profile Banner
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacing),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                                    foregroundColor: AppTheme.primaryColor,
                                    child: Text(
                                      widget.studentSummary.name.isNotEmpty
                                          ? widget.studentSummary.name[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.studentSummary.name,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.studentSummary.email,
                                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          'Phone: ${widget.studentSummary.phone}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Overall Grade
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: overall != null
                                          ? (overall >= 75
                                              ? const Color(0xFFE8F5E9)
                                              : overall >= 50
                                                  ? const Color(0xFFFFF8E1)
                                                  : const Color(0xFFFFEBEE))
                                          : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('Overall', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        Text(
                                          overallDisplay,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: overall != null
                                                ? (overall >= 75
                                                    ? AppTheme.successColor
                                                    : overall >= 50
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
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Evaluation History Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Evaluation History',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${_grades.length} recorded',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_grades.isEmpty)
                            EmptyState(
                              icon: Icons.grade_outlined,
                              title: 'No Grades Awarded Yet',
                              message:
                                  'Tap the "+ Add Grade" button below to record the first quiz, assignment, or test marks for this student.',
                              actionLabel: 'Add First Grade',
                              onAction: _showAddGradeDialog,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _grades.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final grade = _grades[index];
                                final pct = grade.percentage;
                                final color = pct >= 75
                                    ? AppTheme.successColor
                                    : pct >= 50
                                        ? AppTheme.warningColor
                                        : AppTheme.errorColor;

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.spacing),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                grade.assessmentTitle,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                grade.percentageString,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Score: ${grade.marksObtained} / ${grade.maxMarks}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (grade.remarks != null && grade.remarks!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Remarks: ${grade.remarks}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 80), // Fab space
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
