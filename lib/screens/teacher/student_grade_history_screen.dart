import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Screen allowing teachers to inspect a student's grade history and award new assessment grades.
class StudentGradeHistoryScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final StudentGradeSummary studentSummary;

  const StudentGradeHistoryScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.studentSummary,
  });

  @override
  State<StudentGradeHistoryScreen> createState() => _StudentGradeHistoryScreenState();
}

class _StudentGradeHistoryScreenState extends State<StudentGradeHistoryScreen> {
  StreamSubscription? _gradesSub;
  List<Grade> _grades = [];
  bool _isLoading = true;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _subscribeGrades();
  }

  void _subscribeGrades() {
    _gradesSub = FirestoreService.instance
        .getStudentGradesStream(widget.classroomId, widget.studentSummary.studentId)
        .listen(
      (data) {
        if (mounted) {
          setState(() {
            _grades = data.grades;
            _isFromCache = data.isFromCache;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load grades: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _gradesSub?.cancel();
    super.dispose();
  }

  double? _calculateOverallPercentage() {
    if (_grades.isEmpty) return null;
    final totalObtained = _grades.fold(0.0, (sum, g) => sum + g.marksObtained);
    final totalMax = _grades.fold(0.0, (sum, g) => sum + g.maxMarks);
    if (totalMax <= 0) return 0.0;
    return (totalObtained / totalMax) * 100.0;
  }

  void _showAddGradeDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final maxMarksController = TextEditingController();
    final marksController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Award Assessment Grade',
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: titleController,
                  label: 'Assessment Title',
                  hintText: 'e.g. Midterm Exam, Quiz 1, Project',
                  validator: (v) => Validators.validateRequired(v, 'Assessment Title'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: maxMarksController,
                        label: 'Max Marks',
                        hintText: '1 - 1000',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: Validators.validateMaxMarks,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: marksController,
                        label: 'Marks Obtained',
                        hintText: 'e.g. 85',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final max = double.tryParse(maxMarksController.text.trim());
                          return Validators.validateMarksObtained(v, max);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: remarksController,
                  label: 'Remarks (Optional)',
                  hintText: 'e.g. Excellent work on algorithms',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        confirmText: 'Record Grade',
        onConfirm: () async {
          if (!formKey.currentState!.validate()) return;
          final maxMarks = double.parse(maxMarksController.text.trim());
          final marks = double.parse(marksController.text.trim());

          try {
            await FirestoreService.instance.addGrade(
              classroomId: widget.classroomId,
              studentId: widget.studentSummary.studentId,
              studentName: widget.studentSummary.studentName,
              assessmentTitle: titleController.text,
              maxMarks: maxMarks,
              marksObtained: marks,
              remarks: remarksController.text,
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grade recorded successfully!'), backgroundColor: Colors.green),
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
    final overallPct = _calculateOverallPercentage();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${widget.studentSummary.studentName} - Grades'),
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
            // Student Banner Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentSummary.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${widget.studentSummary.studentEmail} • Phone: ${widget.studentSummary.studentPhone}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cumulative Performance:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: overallPct != null
                              ? (overallPct >= 50 ? Colors.green.shade50 : Colors.red.shade50)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: overallPct != null
                                ? (overallPct >= 50 ? Colors.green.shade300 : Colors.red.shade300)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          overallPct != null ? '${overallPct.toStringAsFixed(1)}%' : 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: overallPct != null
                                ? (overallPct >= 50 ? Colors.green.shade800 : Colors.red.shade800)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Evaluation History
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _grades.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.grade_outlined,
                            title: 'No Grades Awarded',
                            message: 'Tap "Add Grade" below to evaluate this student.',
                            actionText: 'Add Grade',
                            onAction: _showAddGradeDialog,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _grades.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final grade = _grades[index];
                            final pct = grade.percentage;

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            grade.assessmentTitle,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: pct >= 50 ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            grade.percentageString,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: pct >= 50 ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Marks: ${grade.marksObtained} / ${grade.maxMarks}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    if (grade.remarks != null && grade.remarks!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Remarks: ${grade.remarks}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
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
        label: const Text('Add Grade'),
        onPressed: _showAddGradeDialog,
      ),
    );
  }
}
