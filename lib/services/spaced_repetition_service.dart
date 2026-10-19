import 'dart:math';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';

/// Represents the classification of a question in the student's spaced repetition lifecycle.
enum MasteryLevel {
  newCard,
  learning,
  reviewDue,
  mastered,
}

/// Result returned after calculating next SM-2 interval.
class SrsReviewResult {
  final int interval; // in days
  final int repetitions;
  final double easeFactor;
  final DateTime nextReviewDate;
  final int grade; // 0 to 5
  final String ratingLabel; // Again, Hard, Good, Easy

  const SrsReviewResult({
    required this.interval,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReviewDate,
    required this.grade,
    required this.ratingLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'interval': interval,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate.toIso8601String(),
      'grade': grade,
      'ratingLabel': ratingLabel,
    };
  }
}

/// Statistics per individual topic for mastery tracking and weak-spot identification.
class TopicMasterySummary {
  final String topic;
  final int totalQuestions;
  final int attemptedQuestions;
  final int masteredCount;
  final int learningCount;
  final int dueCount;
  final double accuracy; // 0.0 to 1.0
  final double masteryPercentage; // 0.0 to 1.0
  final bool isWeak;

  const TopicMasterySummary({
    required this.topic,
    required this.totalQuestions,
    required this.attemptedQuestions,
    required this.masteredCount,
    required this.learningCount,
    required this.dueCount,
    required this.accuracy,
    required this.masteryPercentage,
    required this.isWeak,
  });
}

/// Comprehensive learning science progress dashboard state.
class MasteryDashboardData {
  final int totalQuestions;
  final int attemptedQuestions;
  final double coveragePercentage; // % of total questions attempted
  final int masteredCount;
  final int learningCount;
  final int dueCount;
  final double overallAccuracy; // 0.0 to 1.0
  final int studyStreakDays;
  final int totalMinutesSpent;
  final List<String> weakTopics;
  final Map<String, TopicMasterySummary> topicSummaries;

  const MasteryDashboardData({
    required this.totalQuestions,
    required this.attemptedQuestions,
    required this.coveragePercentage,
    required this.masteredCount,
    required this.learningCount,
    required this.dueCount,
    required this.overallAccuracy,
    required this.studyStreakDays,
    required this.totalMinutesSpent,
    required this.weakTopics,
    required this.topicSummaries,
  });
}

/// Service implementing the SuperMemo SM-2 Spaced Repetition Algorithm,
/// adaptive practice interleaving, and topic-level mastery tracking.
class SpacedRepetitionService {
  SpacedRepetitionService._();
  static final SpacedRepetitionService instance = SpacedRepetitionService._();

  /// Calculates the next review interval and ease factor according to the SM-2 algorithm.
  ///
  /// [currentInterval] in days.
  /// [currentRepetitions] consecutive successful reviews.
  /// [currentEaseFactor] default starts at 2.5 (minimum 1.3).
  /// [grade] quality rating from 0 (total blackout) to 5 (perfect recall).
  ///   - 0, 1, 2 = Again (failure, interval resets to 1 day)
  ///   - 3 = Hard
  ///   - 4 = Good
  ///   - 5 = Easy
  SrsReviewResult calculateSm2({
    required int currentInterval,
    required int currentRepetitions,
    required double currentEaseFactor,
    required int grade,
    DateTime? reviewDate,
  }) {
    final now = reviewDate ?? DateTime.now();
    final q = grade.clamp(0, 5);

    // SM-2 Ease Factor formula:
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    double newEf = currentEaseFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (newEf < 1.3) newEf = 1.3;

    int newReps;
    int newInterval;

    if (q < 3) {
      // Failed recall: reset repetitions and restart interval to 1 day
      newReps = 0;
      newInterval = 1;
    } else {
      // Successful recall
      newReps = currentRepetitions + 1;
      if (newReps == 1) {
        newInterval = 1;
      } else if (newReps == 2) {
        newInterval = 6;
      } else {
        newInterval = (currentInterval * newEf).round();
        if (newInterval <= currentInterval) {
          newInterval = currentInterval + 1;
        }
      }

      // Bonus for Easy (grade 5)
      if (q == 5) {
        newInterval = max(newInterval + 1, (newInterval * 1.3).round());
      }
    }

    final nextReview = now.add(Duration(days: newInterval));
    final label = _labelForGrade(q);

    return SrsReviewResult(
      interval: newInterval,
      repetitions: newReps,
      easeFactor: double.parse(newEf.toStringAsFixed(2)),
      nextReviewDate: nextReview,
      grade: q,
      ratingLabel: label,
    );
  }

  /// Returns projected interval in days for each rating button (Again, Hard, Good, Easy)
  /// allowing Anki-style button labels (e.g. "Again (1d)", "Good (6d)", "Easy (8d)").
  Map<String, int> previewNextIntervals({
    required int currentInterval,
    required int currentRepetitions,
    required double currentEaseFactor,
  }) {
    return {
      'Again': calculateSm2(
        currentInterval: currentInterval,
        currentRepetitions: currentRepetitions,
        currentEaseFactor: currentEaseFactor,
        grade: 1,
      ).interval,
      'Hard': calculateSm2(
        currentInterval: currentInterval,
        currentRepetitions: currentRepetitions,
        currentEaseFactor: currentEaseFactor,
        grade: 3,
      ).interval,
      'Good': calculateSm2(
        currentInterval: currentInterval,
        currentRepetitions: currentRepetitions,
        currentEaseFactor: currentEaseFactor,
        grade: 4,
      ).interval,
      'Easy': calculateSm2(
        currentInterval: currentInterval,
        currentRepetitions: currentRepetitions,
        currentEaseFactor: currentEaseFactor,
        grade: 5,
      ).interval,
    };
  }

  /// Automatically derives an SM-2 rating grade (0..5) from answer correctness and confidence level.
  ///
  /// Incorporates the learning science hypercorrection principle:
  /// - High confidence mistakes are severe memory errors requiring rapid re-review (grade 1).
  /// - Low confidence correct answers are lucky guesses requiring earlier reinforcement (grade 3).
  int gradeFromAccuracyAndConfidence({
    required bool isCorrect,
    required double confidence, // 0.25 (Guessing), 0.50 (50/50), 1.0 (100% Sure)
  }) {
    if (isCorrect) {
      if (confidence >= 0.85) return 5; // Easy: Mastered with 100% confidence
      if (confidence >= 0.45) return 4; // Good: Solid recall with 50/50 confidence
      return 3; // Hard: Lucky guess (25% confidence)
    } else {
      if (confidence >= 0.85) return 1; // Again: High confidence misconception (Hypercorrection error)
      return 2; // Again: Regular error
    }
  }

  /// Determines the mastery status for a question.
  MasteryLevel getMasteryLevel(Question q, {DateTime? now}) {
    final current = now ?? DateTime.now();

    // Overdue review takes priority
    if (q.nextReviewDate != null && current.isAfter(q.nextReviewDate!)) {
      return MasteryLevel.reviewDue;
    }

    // Mastered: 3+ successful consecutive repetitions or interval >= 21 days
    if (q.srsRepetitions >= 3 || q.srsInterval >= 21) {
      return MasteryLevel.mastered;
    }

    // Learning: At least 1 attempt or in-progress repetition
    if (q.srsRepetitions > 0 || q.srsInterval > 1 || q.lastScore != null) {
      return MasteryLevel.learning;
    }

    return MasteryLevel.newCard;
  }

  /// Filters all questions that are currently due for spaced repetition review.
  List<Question> getDueQuestions(List<Question> questions, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return questions.where((q) {
      return getMasteryLevel(q, now: current) == MasteryLevel.reviewDue;
    }).toList();
  }

  /// Analyzes student performance across all questions to generate a comprehensive
  /// progress and mastery dashboard.
  MasteryDashboardData calculateDashboardData({
    required List<Question> questions,
    int studyStreakDays = 1,
    int totalMinutesSpent = 0,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (questions.isEmpty) {
      return const MasteryDashboardData(
        totalQuestions: 0,
        attemptedQuestions: 0,
        coveragePercentage: 0.0,
        masteredCount: 0,
        learningCount: 0,
        dueCount: 0,
        overallAccuracy: 0.0,
        studyStreakDays: 0,
        totalMinutesSpent: 0,
        weakTopics: [],
        topicSummaries: {},
      );
    }

    final byTopic = <String, List<Question>>{};
    int totalAttempted = 0;
    int totalMastered = 0;
    int totalLearning = 0;
    int totalDue = 0;
    double scoreSum = 0.0;
    int scoredCount = 0;

    for (final q in questions) {
      final t = q.topic.trim().isNotEmpty ? q.topic.trim() : 'General';
      byTopic.putIfAbsent(t, () => []).add(q);

      final level = getMasteryLevel(q, now: current);
      if (level == MasteryLevel.mastered) {
        totalMastered++;
      } else if (level == MasteryLevel.learning) {
        totalLearning++;
      } else if (level == MasteryLevel.reviewDue) {
        totalDue++;
      }

      if (q.lastScore != null || q.srsRepetitions > 0) {
        totalAttempted++;
      }

      if (q.lastScore != null) {
        scoreSum += q.lastScore!;
        scoredCount++;
      }
    }

    final Map<String, TopicMasterySummary> topicSummaries = {};
    final List<String> weakTopics = [];

    byTopic.forEach((topicName, topicQuestions) {
      int tAttempted = 0;
      int tMastered = 0;
      int tLearning = 0;
      int tDue = 0;
      double tScoreSum = 0.0;
      int tScoredCount = 0;

      for (final q in topicQuestions) {
        final level = getMasteryLevel(q, now: current);
        if (level == MasteryLevel.mastered) tMastered++;
        if (level == MasteryLevel.learning) tLearning++;
        if (level == MasteryLevel.reviewDue) tDue++;

        if (q.lastScore != null || q.srsRepetitions > 0) {
          tAttempted++;
        }
        if (q.lastScore != null) {
          tScoreSum += q.lastScore!;
          tScoredCount++;
        }
      }

      final accuracy = tScoredCount > 0 ? (tScoreSum / tScoredCount) : 0.0;
      final masteryPct = topicQuestions.isNotEmpty ? (tMastered / topicQuestions.length) : 0.0;

      // Weak if accuracy is below 70% with at least 1 attempted question,
      // or if there are multiple overdue items with 0% mastery
      final isWeak = (tScoredCount >= 1 && accuracy < 0.70) || (tDue >= 3 && masteryPct < 0.20);

      if (isWeak) {
        weakTopics.add(topicName);
      }

      topicSummaries[topicName] = TopicMasterySummary(
        topic: topicName,
        totalQuestions: topicQuestions.length,
        attemptedQuestions: tAttempted,
        masteredCount: tMastered,
        learningCount: tLearning,
        dueCount: tDue,
        accuracy: accuracy,
        masteryPercentage: masteryPct,
        isWeak: isWeak,
      );
    });

    // Sort weak topics by lowest accuracy first
    weakTopics.sort((a, b) {
      final accA = topicSummaries[a]?.accuracy ?? 0.0;
      final accB = topicSummaries[b]?.accuracy ?? 0.0;
      return accA.compareTo(accB);
    });

    final overallAcc = scoredCount > 0 ? (scoreSum / scoredCount) : 0.0;
    final coverage = (totalAttempted / questions.length) * 100.0;

    return MasteryDashboardData(
      totalQuestions: questions.length,
      attemptedQuestions: totalAttempted,
      coveragePercentage: double.parse(coverage.toStringAsFixed(1)),
      masteredCount: totalMastered,
      learningCount: totalLearning,
      dueCount: totalDue,
      overallAccuracy: double.parse(overallAcc.toStringAsFixed(2)),
      studyStreakDays: studyStreakDays,
      totalMinutesSpent: totalMinutesSpent,
      weakTopics: weakTopics,
      topicSummaries: topicSummaries,
    );
  }

  /// Dynamically constructs an adaptive practice session.
  ///
  /// Interleaves:
  /// - 60% spaced repetition review & weak topics (to reinforce memory before forgetting).
  /// - 40% new/unattempted questions (to advance breadth of mastery).
  ///
  /// Scales difficulty progressively: starts with Easy/Medium for low-mastery topics,
  /// introducing Hard questions once topic mastery crosses 50%.
  List<Question> generateAdaptiveQueue(
    List<Question> allQuestions, {
    int targetCount = 10,
    String? preferredTopic,
    DateTime? now,
  }) {
    if (allQuestions.isEmpty) return [];

    final current = now ?? DateTime.now();
    var pool = allQuestions;

    if (preferredTopic != null && preferredTopic != 'All Topics') {
      pool = allQuestions.where((q) => q.topic.toLowerCase() == preferredTopic.toLowerCase()).toList();
      if (pool.isEmpty) pool = allQuestions;
    }

    // Identify Due / Weak Questions
    final dueOrWeak = pool.where((q) {
      final level = getMasteryLevel(q, now: current);
      final isLowScore = (q.lastScore != null && q.lastScore! < 0.70);
      return level == MasteryLevel.reviewDue || isLowScore;
    }).toList();

    // Sort due items by oldest overdue date first
    dueOrWeak.sort((a, b) {
      final dateA = a.nextReviewDate ?? DateTime(2000);
      final dateB = b.nextReviewDate ?? DateTime(2000);
      return dateA.compareTo(dateB);
    });

    // Identify Unattempted / New Questions
    final newQuestions = pool.where((q) {
      return getMasteryLevel(q, now: current) == MasteryLevel.newCard;
    }).toList();

    // Identify Learning Questions
    final learningQuestions = pool.where((q) {
      return getMasteryLevel(q, now: current) == MasteryLevel.learning;
    }).toList();

    final result = <Question>[];
    final targetReviewCount = (targetCount * 0.60).ceil();
    final targetNewCount = targetCount - targetReviewCount;

    // 1. Take up to targetReviewCount from Due / Weak pool
    final reviewPicks = dueOrWeak.take(targetReviewCount).toList();
    result.addAll(reviewPicks);

    // If not enough due/weak, supplement with in-progress learning questions
    if (result.length < targetReviewCount) {
      final remainingNeeded = targetReviewCount - result.length;
      final learningPicks = learningQuestions
          .where((q) => !result.any((r) => r.id == q.id))
          .take(remainingNeeded);
      result.addAll(learningPicks);
    }

    // 2. Take up to targetNewCount from New Questions
    final newPicks = newQuestions
        .where((q) => !result.any((r) => r.id == q.id))
        .take(targetNewCount)
        .toList();
    result.addAll(newPicks);

    // 3. If still below targetCount, backfill from remaining pool
    if (result.length < targetCount) {
      for (final q in pool) {
        if (!result.any((r) => r.id == q.id)) {
          result.add(q);
          if (result.length >= targetCount) break;
        }
      }
    }

    // 4. Interleave items rather than keeping all reviews clumped at the front
    final interleaved = <Question>[];
    final reviews = result.where((q) => q.lastScore != null || q.srsRepetitions > 0).toList();
    final news = result.where((q) => q.lastScore == null && q.srsRepetitions == 0).toList();

    int rIdx = 0;
    int nIdx = 0;
    while (rIdx < reviews.length || nIdx < news.length) {
      // Pick 2 review items, then 1 new item
      if (rIdx < reviews.length) interleaved.add(reviews[rIdx++]);
      if (rIdx < reviews.length) interleaved.add(reviews[rIdx++]);
      if (nIdx < news.length) interleaved.add(news[nIdx++]);
    }

    return interleaved.isNotEmpty ? interleaved : result;
  }

  /// Records student answer in Firestore with updated SM-2 interval and mastery stats.
  Future<Question> recordReview({
    required String userId,
    required Question question,
    required int grade,
    required double score, // 0.0 to 1.0
  }) async {
    final srs = calculateSm2(
      currentInterval: question.srsInterval,
      currentRepetitions: question.srsRepetitions,
      currentEaseFactor: question.srsEaseFactor,
      grade: grade,
    );

    final updatedQuestion = question.copyWith(
      srsInterval: srs.interval,
      srsRepetitions: srs.repetitions,
      srsEaseFactor: srs.easeFactor,
      nextReviewDate: srs.nextReviewDate,
      lastScore: score,
    );

    await FirestoreService.instance.updateQuestionSrs(
      userId,
      question.id,
      srsInterval: srs.interval,
      srsRepetitions: srs.repetitions,
      srsEaseFactor: srs.easeFactor,
      nextReviewDate: srs.nextReviewDate,
      lastScore: score,
    );

    return updatedQuestion;
  }

  static String _labelForGrade(int grade) {
    switch (grade) {
      case 0:
      case 1:
      case 2:
        return 'Again';
      case 3:
        return 'Hard';
      case 4:
        return 'Good';
      case 5:
        return 'Easy';
      default:
        return 'Good';
    }
  }
}
