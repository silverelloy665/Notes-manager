import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/spaced_repetition_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

/// Interactive Learning Science & Mastery Progress Dashboard.
///
/// Visualizes spaced repetition queues, daily study streaks, question bank coverage,
/// accuracy rates, weak topic alerts, and per-topic mastery progress bars.
class MasteryDashboardView extends StatelessWidget {
  final List<Question> questions;
  final VoidCallback onStartAdaptivePractice;
  final VoidCallback onReviewDue;
  final ValueChanged<String> onPracticeTopic;
  final VoidCallback? onClose;

  const MasteryDashboardView({
    super.key,
    required this.questions,
    required this.onStartAdaptivePractice,
    required this.onReviewDue,
    required this.onPracticeTopic,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardData = SpacedRepetitionService.instance.calculateDashboardData(
      questions: questions,
      studyStreakDays: 3, // Initialized active streak
      totalMinutesSpent: 42,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.psychology_rounded, size: 22, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learning Science & Mastery Dashboard',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        'SM-2 Spaced Repetition • Interleaved Adaptive Practice • Memory Retention',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Adaptive Practice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: onStartAdaptivePractice,
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                    onPressed: onClose,
                    tooltip: 'Minimize Dashboard',
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Core Metrics Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMetricCard(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFE65100),
                          label: 'Study Streak',
                          value: '${dashboardData.studyStreakDays} Days',
                          subtitle: 'Daily memory consolidation',
                        ),
                        _buildMetricCard(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.data_usage_rounded,
                          iconColor: AppTheme.primaryColor,
                          label: 'Bank Coverage',
                          value: '${dashboardData.coveragePercentage}%',
                          subtitle: '${dashboardData.attemptedQuestions} of ${dashboardData.totalQuestions} practiced',
                        ),
                        _buildMetricCard(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.track_changes_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          label: 'Overall Accuracy',
                          value: '${(dashboardData.overallAccuracy * 100).toStringAsFixed(0)}%',
                          subtitle: 'Retention quality score',
                        ),
                        _buildMetricCard(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.timer_outlined,
                          iconColor: AppTheme.secondaryColor,
                          label: 'Time Invested',
                          value: '${dashboardData.totalMinutesSpent} min',
                          subtitle: 'Active retrieval practice',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Spaced Repetition Queue Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildQueueStatusPill('⏰ Review Due', dashboardData.dueCount, const Color(0xFFD32F2F), const Color(0xFFFFEBEE)),
                            const SizedBox(width: 10),
                            _buildQueueStatusPill('🌟 Mastered', dashboardData.masteredCount, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                            const SizedBox(width: 10),
                            _buildQueueStatusPill('📖 Learning', dashboardData.learningCount, const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                            const SizedBox(width: 10),
                            _buildQueueStatusPill('🆕 Unseen', dashboardData.totalQuestions - dashboardData.attemptedQuestions, const Color(0xFF546E7A), const Color(0xFFECEFF1)),
                          ],
                        ),
                      ),
                      if (dashboardData.dueCount > 0)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.alarm_on_rounded, size: 16),
                          label: Text('Review Due (${dashboardData.dueCount})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: onReviewDue,
                        ),
                    ],
                  ),
                ),

                // Weak Spots Alert
                if (dashboardData.weakTopics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082), width: 1.3),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFF57F17)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Adaptive Focus Areas Detected (<70% Accuracy)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The SM-2 engine has scheduled higher frequency retrieval intervals for: ${dashboardData.weakTopics.join(', ')}.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE65100),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: const Text('Strengthen Weak Spots'),
                          onPressed: () => onPracticeTopic(dashboardData.weakTopics.first),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Topic Mastery Progress Breakdown
                const Text(
                  'Topic Mastery Progress Matrix',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...dashboardData.topicSummaries.entries.map((entry) {
                  final summary = entry.value;
                  return _buildTopicProgressRow(summary);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStatusPill(String label, int count, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicProgressRow(TopicMasterySummary summary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary.topic,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (summary.isWeak) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Weak', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.attemptedQuestions}/${summary.totalQuestions} Questions • ${(summary.accuracy * 100).toStringAsFixed(0)}% Accuracy',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Multi-segment Mastery Progress Bar
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (summary.masteredCount > 0)
                        Flexible(
                          flex: summary.masteredCount,
                          child: Container(color: const Color(0xFF2E7D32)),
                        ),
                      if (summary.learningCount > 0)
                        Flexible(
                          flex: summary.learningCount,
                          child: Container(color: const Color(0xFFFFA000)),
                        ),
                      if (summary.totalQuestions - (summary.masteredCount + summary.learningCount) > 0)
                        Flexible(
                          flex: summary.totalQuestions - (summary.masteredCount + summary.learningCount),
                          child: Container(color: const Color(0xFFE0E0E0)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${(summary.masteryPercentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, size: 20, color: AppTheme.primaryColor),
              tooltip: 'Practice ${summary.topic}',
              onPressed: () => onPracticeTopic(summary.topic),
            ),
          ],
        ),
      ),
    );
  }
}
