import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studymate_classroom/models/summary_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';

/// Represents a version entry for a classroom note revision.
class NoteVersion {
  final int version;
  final String fileName;
  final DateTime? uploadedAt;
  final String? note;

  const NoteVersion({
    required this.version,
    required this.fileName,
    this.uploadedAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'fileName': fileName,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      'note': note ?? '',
    };
  }

  factory NoteVersion.fromMap(Map<String, dynamic> map) {
    DateTime? parsedUploadedAt;
    final rawDate = map['uploadedAt'];
    if (rawDate is Timestamp) {
      parsedUploadedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedUploadedAt = DateTime.tryParse(rawDate);
    }

    return NoteVersion(
      version: (map['version'] ?? 1) as int,
      fileName: (map['fileName'] ?? '') as String,
      uploadedAt: parsedUploadedAt,
      note: map['note'] as String?,
    );
  }
}

/// Represents lecture notes, slides, documents, or external resources uploaded to a classroom.
class ClassroomNote {
  final String id;
  final String classroomId;
  final int unitNumber;
  final String unitTitle;
  final String title;
  final String? description;
  final String fileType; // 'pdf', 'pptx', 'docx', 'image', 'link', 'txt'
  final String? fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String extractedText;
  final TopicMap? topicMap;
  final MultiLevelSummary? summary;
  final String status; // 'draft' | 'published'
  final DateTime? scheduledPublishAt;
  final bool allowDownload;
  final int version;
  final List<NoteVersion> versionHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClassroomNote({
    required this.id,
    required this.classroomId,
    this.unitNumber = 1,
    this.unitTitle = 'Unit 1: Overview & Fundamentals',
    required this.title,
    this.description,
    this.fileType = 'pdf',
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.extractedText = '',
    this.topicMap,
    this.summary,
    this.status = 'published',
    this.scheduledPublishAt,
    this.allowDownload = true,
    this.version = 1,
    this.versionHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isPublished => status == 'published' && (scheduledPublishAt == null || DateTime.now().isAfter(scheduledPublishAt!));
  bool get isDraft => status == 'draft';
  bool get isScheduled => status == 'published' && scheduledPublishAt != null && DateTime.now().isBefore(scheduledPublishAt!);

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'unitNumber': unitNumber,
      'unitTitle': unitTitle,
      'title': title,
      'description': description ?? '',
      'fileType': fileType,
      'fileUrl': fileUrl ?? '',
      'fileName': fileName ?? '',
      'fileSizeBytes': fileSizeBytes,
      'extractedText': extractedText,
      'topicMap': topicMap?.toMap(),
      'summary': summary?.toMap(),
      'status': status,
      'scheduledPublishAt': scheduledPublishAt != null ? Timestamp.fromDate(scheduledPublishAt!) : null,
      'allowDownload': allowDownload,
      'version': version,
      'versionHistory': versionHistory.map((v) => v.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClassroomNote.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedCreatedAt;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated);
    }

    DateTime? parsedUpdatedAt;
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      parsedUpdatedAt = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated);
    }

    DateTime? parsedScheduled;
    final rawScheduled = map['scheduledPublishAt'];
    if (rawScheduled is Timestamp) {
      parsedScheduled = rawScheduled.toDate();
    } else if (rawScheduled is String) {
      parsedScheduled = DateTime.tryParse(rawScheduled);
    }

    TopicMap? parsedTopicMap;
    if (map['topicMap'] is Map<String, dynamic>) {
      parsedTopicMap = TopicMap.fromMap(map['topicMap'] as Map<String, dynamic>, docId);
    } else if (map['topicMap'] is Map) {
      parsedTopicMap = TopicMap.fromMap(Map<String, dynamic>.from(map['topicMap'] as Map), docId);
    }

    MultiLevelSummary? parsedSummary;
    if (map['summary'] is Map<String, dynamic>) {
      parsedSummary = MultiLevelSummary.fromMap(map['summary'] as Map<String, dynamic>);
    } else if (map['summary'] is Map) {
      parsedSummary = MultiLevelSummary.fromMap(Map<String, dynamic>.from(map['summary'] as Map));
    }

    final rawHistory = map['versionHistory'];
    final List<NoteVersion> parsedHistory = [];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is Map<String, dynamic>) {
          parsedHistory.add(NoteVersion.fromMap(h));
        } else if (h is Map) {
          parsedHistory.add(NoteVersion.fromMap(Map<String, dynamic>.from(h)));
        }
      }
    }

    return ClassroomNote(
      id: docId,
      classroomId: (map['classroomId'] ?? '') as String,
      unitNumber: (map['unitNumber'] ?? 1) as int,
      unitTitle: (map['unitTitle'] ?? 'Unit 1') as String,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      fileType: (map['fileType'] ?? 'pdf') as String,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int?,
      extractedText: (map['extractedText'] ?? '') as String,
      topicMap: parsedTopicMap,
      summary: parsedSummary,
      status: (map['status'] ?? 'published') as String,
      scheduledPublishAt: parsedScheduled,
      allowDownload: (map['allowDownload'] ?? true) as bool,
      version: (map['version'] ?? 1) as int,
      versionHistory: parsedHistory,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  ClassroomNote copyWith({
    String? id,
    String? classroomId,
    int? unitNumber,
    String? unitTitle,
    String? title,
    String? description,
    String? fileType,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    String? extractedText,
    TopicMap? topicMap,
    MultiLevelSummary? summary,
    String? status,
    DateTime? scheduledPublishAt,
    bool? allowDownload,
    int? version,
    List<NoteVersion>? versionHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassroomNote(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      unitNumber: unitNumber ?? this.unitNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      fileType: fileType ?? this.fileType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      extractedText: extractedText ?? this.extractedText,
      topicMap: topicMap ?? this.topicMap,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      scheduledPublishAt: scheduledPublishAt ?? this.scheduledPublishAt,
      allowDownload: allowDownload ?? this.allowDownload,
      version: version ?? this.version,
      versionHistory: versionHistory ?? this.versionHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

