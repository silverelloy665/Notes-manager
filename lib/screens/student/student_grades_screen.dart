import 'package:flutter/material.dart';
import '../../models/classroom_model.dart';
import '../../models/grade_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';

/// Screen displaying a student's assessment scores, percentage breakdowns, and overall course average.
class StudentGradesScreen extends StatefulWidget {
  final Classroom classroom;
  final User student;

  const StudentGradesScreen({
    super.key,
    required this.classroom,
    required this.student,
  });

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
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
        widget.student.id!,
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

  @override
  Widget build(BuildContext context) {
    final overall = _calculateOverallPercentage();
    final overallDisplay = overall != null ? '${overall.toStringAsFixed(1)}%' : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom.name),
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
                          // Classroom Summary Card
                          Card(
                            color: AppTheme.primaryColor,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.classroom.subject.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Code: ${widget.classroom.code}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.classroom.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (widget.classroom.teacherName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Instructor: ${widget.classroom.teacherName}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  const Divider(color: Colors.white24, height: 1),
                                  const SizedBox(height: 14),

                                  // Performance Metrics
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          const Text(
                                            'Overall Grade',
                                            style: TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            overallDisplay,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(height: 36, width: 1, color: Colors.white24),
                                      Column(
                                        children: [
                                          const Text(
                                            'Evaluations',
                                            style: TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_grades.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Grades Header
                          const Text(
                            'Assessment Breakdown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (_grades.isEmpty)
                            const EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No Grades Recorded Yet',
                              message:
                                  'Your instructor has not posted any evaluated assessments or quiz marks for you in this class yet.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _grades.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final grade = _grades[index];
                                return _StudentGradeItemCard(grade: grade);
                              },
                            ),
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

class _StudentGradeItemCard extends StatelessWidget {
  final Grade grade;

  const _StudentGradeItemCard({required this.grade});

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    grade.percentageString,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Marks display
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'Marks: ${grade.marksObtained} / ${grade.maxMarks}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            if (grade.remarks != null && grade.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Remarks: ${grade.remarks}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
