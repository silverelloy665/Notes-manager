import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Screen displaying a student's assessment scores, percentage breakdowns, and overall course average.
class StudentGradesScreen extends StatefulWidget {
  final Classroom classroom;
  final String studentId;
  final String studentName;

  const StudentGradesScreen({
    super.key,
    required this.classroom,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
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
        .getStudentGradesStream(widget.classroom.id, widget.studentId)
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

  @override
  Widget build(BuildContext context) {
    final overallPct = _calculateOverallPercentage();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.classroom.name),
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
            // Overall Grade Header Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF5C6BC0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classroom.subject,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.studentName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cumulative Performance',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          overallPct != null ? '${overallPct.toStringAsFixed(1)}%' : 'N/A',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Assessment History List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _grades.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.grade_outlined,
                            title: 'No Grades Awarded Yet',
                            message: 'Your instructor has not published any evaluations for this classroom yet.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _grades.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                                            border: Border.all(
                                              color: pct >= 50 ? Colors.green.shade200 : Colors.red.shade200,
                                            ),
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
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Text(
                                          'Score: ${grade.marksObtained} / ${grade.maxMarks}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        if (grade.createdAt != null) ...[
                                          const Spacer(),
                                          Text(
                                            '${grade.createdAt!.day}/${grade.createdAt!.month}/${grade.createdAt!.year}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (grade.remarks != null && grade.remarks!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Remarks: ${grade.remarks}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                        ),
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
    );
  }
}
