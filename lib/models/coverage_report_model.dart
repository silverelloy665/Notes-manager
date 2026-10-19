import 'package:cloud_firestore/cloud_firestore.dart';

/// Topic-specific question coverage statistics.
class TopicCoverageStats {
  final String topic;
  final int totalQuestions;
  final int mcqCount;
  final int conceptualCount;
  final int easyCount;
  final int mediumCount;
  final int hardCount;
  final int coveredSubtopics;
  final int totalSubtopics;
  final bool isFullyCovered;

  const TopicCoverageStats({
    required this.topic,
    required this.totalQuestions,
    required this.mcqCount,
    required this.conceptualCount,
    required this.easyCount,
    required this.mediumCount,
    required this.hardCount,
    required this.coveredSubtopics,
    required this.totalSubtopics,
    required this.isFullyCovered,
  });

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'totalQuestions': totalQuestions,
      'mcqCount': mcqCount,
      'conceptualCount': conceptualCount,
      'easyCount': easyCount,
      'mediumCount': mediumCount,
      'hardCount': hardCount,
      'coveredSubtopics': coveredSubtopics,
      'totalSubtopics': totalSubtopics,
      'isFullyCovered': isFullyCovered,
    };
  }

  factory TopicCoverageStats.fromMap(Map<String, dynamic> map) {
    return TopicCoverageStats(
      topic: (map['topic'] ?? '') as String,
      totalQuestions: (map['totalQuestions'] ?? 0) as int,
      mcqCount: (map['mcqCount'] ?? 0) as int,
      conceptualCount: (map['conceptualCount'] ?? 0) as int,
      easyCount: (map['easyCount'] ?? 0) as int,
      mediumCount: (map['mediumCount'] ?? 0) as int,
      hardCount: (map['hardCount'] ?? 0) as int,
      coveredSubtopics: (map['coveredSubtopics'] ?? 0) as int,
      totalSubtopics: (map['totalSubtopics'] ?? 0) as int,
      isFullyCovered: (map['isFullyCovered'] ?? false) as bool,
    );
  }
}

/// Comprehensive, verifiable coverage report for an uploaded document.
/// Proves that 100% of topics, subtopics, slides, and pages are covered by the Question Bank.
class CoverageReport {
  final String documentId;
  final String fileName;
  final int totalQuestions;
  final int mcqCount;
  final int conceptualCount;
  final int totalPages;
  final List<int> coveredPages;
  final double pageCoveragePercentage;
  final Map<String, TopicCoverageStats> topicStats;
  final List<int> uncoveredPages;
  final List<String> uncoveredSubtopics;
  final bool is100PercentCovered;
  final DateTime generatedAt;

  const CoverageReport({
    required this.documentId,
    required this.fileName,
    required this.totalQuestions,
    required this.mcqCount,
    required this.conceptualCount,
    required this.totalPages,
    required this.coveredPages,
    required this.pageCoveragePercentage,
    required this.topicStats,
    this.uncoveredPages = const [],
    this.uncoveredSubtopics = const [],
    required this.is100PercentCovered,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'fileName': fileName,
      'totalQuestions': totalQuestions,
      'mcqCount': mcqCount,
      'conceptualCount': conceptualCount,
      'totalPages': totalPages,
      'coveredPages': coveredPages,
      'pageCoveragePercentage': pageCoveragePercentage,
      'topicStats': topicStats.map((k, v) => MapEntry(k, v.toMap())),
      'uncoveredPages': uncoveredPages,
      'uncoveredSubtopics': uncoveredSubtopics,
      'is100PercentCovered': is100PercentCovered,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory CoverageReport.fromMap(Map<String, dynamic> map) {
    final rawStats = map['topicStats'] as Map? ?? {};
    final stats = <String, TopicCoverageStats>{};
    rawStats.forEach((key, val) {
      if (val is Map) {
        stats[key.toString()] = TopicCoverageStats.fromMap(Map<String, dynamic>.from(val));
      }
    });

    final rawPages = map['coveredPages'] as List? ?? [];
    final rawUncovered = map['uncoveredPages'] as List? ?? [];
    final rawUncoveredSub = map['uncoveredSubtopics'] as List? ?? [];

    DateTime genDate;
    final rawDate = map['generatedAt'];
    if (rawDate is Timestamp) {
      genDate = rawDate.toDate();
    } else if (rawDate is String) {
      genDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      genDate = DateTime.now();
    }

    return CoverageReport(
      documentId: (map['documentId'] ?? '') as String,
      fileName: (map['fileName'] ?? '') as String,
      totalQuestions: (map['totalQuestions'] ?? 0) as int,
      mcqCount: (map['mcqCount'] ?? 0) as int,
      conceptualCount: (map['conceptualCount'] ?? 0) as int,
      totalPages: (map['totalPages'] ?? 1) as int,
      coveredPages: rawPages.map((p) => (p as num).toInt()).toList(),
      pageCoveragePercentage: ((map['pageCoveragePercentage'] ?? 0.0) as num).toDouble(),
      topicStats: stats,
      uncoveredPages: rawUncovered.map((p) => (p as num).toInt()).toList(),
      uncoveredSubtopics: rawUncoveredSub.map((s) => s.toString()).toList(),
      is100PercentCovered: (map['is100PercentCovered'] ?? false) as bool,
      generatedAt: genDate,
    );
  }
}

