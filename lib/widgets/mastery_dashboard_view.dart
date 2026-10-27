import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/spaced_repetition_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/botanical_charts.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

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
    final isDark = AppTheme.isDark(context);
    final dashboardData = SpacedRepetitionService.instance.calculateDashboardData(
      questions: questions,
      studyStreakDays: 3, // Initialized active streak
      totalMinutesSpent: 42,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSageCard : Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.primaryColor).withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Responsive Header that never wraps title text into single letters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSlateBase : AppTheme.primaryLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;

                final iconWidget = Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D38) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: (isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor).withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.psychology_rounded, size: 22, color: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor),
                );

                final titleWidget = Text(
                  'Learning Science & Mastery Dashboard',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: isNarrow ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor,
                  ),
                );

                final subtitleWidget = Text(
                  'SM-2 Spaced Repetition • Interleaved Adaptive Practice • Memory Retention',
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary),
                );

                final adaptiveBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor,
                    foregroundColor: isDark ? AppTheme.darkSlateBase : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Adaptive Practice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: onStartAdaptivePractice,
                );

                final closeBtn = onClose != null
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary),
                        onPressed: onClose,
                        tooltip: 'Minimize Dashboard',
                      )
                    : null;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          iconWidget,
                          const SizedBox(width: 10),
                          Expanded(child: titleWidget),
                          if (closeBtn != null) closeBtn,
                        ],
                      ),
                      const SizedBox(height: 6),
                      subtitleWidget,
                      const SizedBox(height: 12),
                      adaptiveBtn,
                    ],
                  );
                }

                return Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          subtitleWidget,
                        ],
                      ),
                    ),
                    adaptiveBtn,
                    if (closeBtn != null) ...[
                      const SizedBox(width: 8),
                      closeBtn,
                    ],
                  ],
                );
              },
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
                          isDark: isDark,
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFE65100),
                          label: 'Study Streak',
                          value: '${dashboardData.studyStreakDays} Days',
                          subtitle: 'Daily memory consolidation',
                        ),
                        _buildMetricCard(
                          isDark: isDark,
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.data_usage_rounded,
                          iconColor: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor,
                          label: 'Bank Coverage',
                          value: '${dashboardData.coveragePercentage}%',
                          subtitle: '${dashboardData.attemptedQuestions} of ${dashboardData.totalQuestions} practiced',
                        ),
                        _buildMetricCard(
                          isDark: isDark,
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.track_changes_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          label: 'Overall Accuracy',
                          value: '${(dashboardData.overallAccuracy * 100).toStringAsFixed(0)}%',
                          subtitle: 'Retention quality score',
                        ),
                        _buildMetricCard(
                          isDark: isDark,
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 36) / 4,
                          icon: Icons.timer_outlined,
                          iconColor: isDark ? const Color(0xFF80CBC4) : AppTheme.secondaryColor,
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
                    color: isDark ? AppTheme.darkSlateBase : const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQueueStatusPill('⏰ Review Due', dashboardData.dueCount, const Color(0xFFD32F2F), isDark ? const Color(0xFF3B1F22) : const Color(0xFFFFEBEE)),
                          _buildQueueStatusPill('🌟 Mastered', dashboardData.masteredCount, const Color(0xFF2E7D32), isDark ? const Color(0xFF1B3522) : const Color(0xFFE8F5E9)),
                          _buildQueueStatusPill('📖 Learning', dashboardData.learningCount, const Color(0xFFE65100), isDark ? const Color(0xFF382A1C) : const Color(0xFFFFF3E0)),
                          _buildQueueStatusPill('🆕 Unseen', dashboardData.totalQuestions - dashboardData.attemptedQuestions, const Color(0xFF78909C), isDark ? const Color(0xFF243238) : const Color(0xFFECEFF1)),
                        ],
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
                      color: isDark ? const Color(0xFF332A15) : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF8D6E18) : const Color(0xFFFFE082), width: 1.3),
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
                              Text(
                                'Adaptive Focus Areas Detected (<70% Accuracy)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFFFFE082) : const Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The SM-2 engine has scheduled higher frequency retrieval intervals for: ${dashboardData.weakTopics.join(', ')}.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFFFECB3) : const Color(0xFF5D4037),
                                  height: 1.35,
                                ),
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

                const SizedBox(height: 20),

                // Botanical Visual Analytics (Donut Mastery & Vine Progression Chart)
                WatercolorBlobContainer(
                  variant: BlobVariant.sageSoft,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.eco_rounded, size: 18, color: isDark ? AppTheme.darkLightGreen : AppTheme.inkForest),
                          const SizedBox(width: 8),
                          Text(
                            'Botanical Learning Analytics',
                            style: TextStyle(
                              fontFamily: AppTheme.fontCardo,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 550;
                          final totalQ = dashboardData.totalQuestions > 0 ? dashboardData.totalQuestions.toDouble() : 1.0;
                          final masteredPct = (dashboardData.masteredCount / totalQ) * 100;
                          final learningPct = (dashboardData.learningCount / totalQ) * 100;
                          final duePct = (dashboardData.dueCount / totalQ) * 100;

                          final vinePoints = [
                            const VineChartDataPoint(label: 'Day 1', value: 60, displayValue: '60%'),
                            const VineChartDataPoint(label: 'Day 2', value: 72, displayValue: '72%'),
                            const VineChartDataPoint(label: 'Day 3', value: 80, displayValue: '80%'),
                            VineChartDataPoint(
                              label: 'Today',
                              value: (dashboardData.overallAccuracy * 100).clamp(5.0, 100.0),
                              displayValue: '${(dashboardData.overallAccuracy * 100).toStringAsFixed(0)}%',
                            ),
                          ];

                          final donutWidget = BotanicalDonutChart(
                            masteredPercent: masteredPct,
                            learningPercent: learningPct,
                            reviewDuePercent: duePct,
                            centerTitle: '${(dashboardData.overallAccuracy * 100).toStringAsFixed(0)}%',
                            centerSubtitle: 'Mastery',
                          );

                          final lineChartWidget = BotanicalVineLineChart(
                            points: vinePoints,
                            chartTitle: 'Retention Accuracy Progression',
                            height: 160,
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                donutWidget,
                                const SizedBox(width: 24),
                                Expanded(child: lineChartWidget),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                Center(child: donutWidget),
                                const SizedBox(height: 18),
                                lineChartWidget,
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Topic Mastery Progress Breakdown
                Text(
                  'Topic Mastery Progress Matrix',
                  style: TextStyle(
                    fontFamily: AppTheme.fontCardo,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
                  ),
                ),
                const SizedBox(height: 10),
                ...dashboardData.topicSummaries.entries.map((entry) {
                  final summary = entry.value;
                  return _buildTopicProgressRow(summary, isDark);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
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
        color: isDark ? AppTheme.darkSlateBase : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
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
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE8F5E9) : AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary),
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
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
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

  Widget _buildTopicProgressRow(TopicMasterySummary summary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSlateBase : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 480;

            final topicBadge = Row(
              children: [
                Flexible(
                  child: Text(
                    summary.topic,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE8F5E9) : AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (summary.isWeak) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3E1F23) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Weak', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                  ),
                ],
              ],
            );

            final subtitleInfo = Text(
              '${summary.attemptedQuestions}/${summary.totalQuestions} Questions • ${(summary.accuracy * 100).toStringAsFixed(0)}% Accuracy',
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary),
            );

            final progressBar = ClipRRect(
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
                        child: Container(color: isDark ? const Color(0xFF2E4D38) : const Color(0xFFE0E0E0)),
                      ),
                  ],
                ),
              ),
            );

            final pctAndBtn = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(summary.masteryPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.play_circle_outline_rounded, size: 20, color: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor),
                  tooltip: 'Practice ${summary.topic}',
                  onPressed: () => onPracticeTopic(summary.topic),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: topicBadge),
                      pctAndBtn,
                    ],
                  ),
                  const SizedBox(height: 2),
                  subtitleInfo,
                  const SizedBox(height: 8),
                  progressBar,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      topicBadge,
                      const SizedBox(height: 3),
                      subtitleInfo,
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: progressBar),
                const SizedBox(width: 14),
                pctAndBtn,
              ],
            );
          },
        ),
      ),
    );
  }
}

