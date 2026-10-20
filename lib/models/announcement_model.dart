import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attachment included in a classroom stream announcement.
class AnnouncementAttachment {
  final String name;
  final String url;
  final String type; // 'file', 'link', 'note', 'pdf'
  final int? sizeBytes;

  const AnnouncementAttachment({
    required this.name,
    required this.url,
    this.type = 'file',
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'type': type,
      'sizeBytes': sizeBytes,
    };
  }

  factory AnnouncementAttachment.fromMap(Map<String, dynamic> map) {
    return AnnouncementAttachment(
      name: (map['name'] ?? '') as String,
      url: (map['url'] ?? '') as String,
      type: (map['type'] ?? 'file') as String,
      sizeBytes: map['sizeBytes'] as int?,
    );
  }
}

/// Represents a classroom stream announcement / post.
class Announcement {
  final String id;
  final String classroomId;
  final String authorId;
  final String authorName;
  final String authorRole; // 'Teacher' or 'Student'
  final String content;
  final List<AnnouncementAttachment> attachments;
  final bool pinned;
  final int commentCount;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.classroomId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    this.attachments = const [],
    this.pinned = false,
    this.commentCount = 0,
    this.createdAt,
  });

  bool get isTeacherPost => authorRole == 'Teacher';

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'content': content,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'pinned': pinned,
      'commentCount': commentCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    final rawAttachments = map['attachments'];
    final List<AnnouncementAttachment> parsedAttachments = [];
    if (rawAttachments is List) {
      for (final a in rawAttachments) {
        if (a is Map<String, dynamic>) {
          parsedAttachments.add(AnnouncementAttachment.fromMap(a));
        } else if (a is Map) {
          parsedAttachments.add(AnnouncementAttachment.fromMap(Map<String, dynamic>.from(a)));
        }
      }
    }

    return Announcement(
      id: docId,
      classroomId: (map['classroomId'] ?? '') as String,
      authorId: (map['authorId'] ?? '') as String,
      authorName: (map['authorName'] ?? 'Instructor') as String,
      authorRole: (map['authorRole'] ?? 'Teacher') as String,
      content: (map['content'] ?? '') as String,
      attachments: parsedAttachments,
      pinned: (map['pinned'] ?? false) as bool,
      commentCount: (map['commentCount'] ?? 0) as int,
      createdAt: parsedCreatedAt,
    );
  }

  Announcement copyWith({
    String? id,
    String? classroomId,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? content,
    List<AnnouncementAttachment>? attachments,
    bool? pinned,
    int? commentCount,
    DateTime? createdAt,
  }) {
    return Announcement(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      pinned: pinned ?? this.pinned,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a comment on a classroom stream announcement.
class AnnouncementComment {
  final String id;
  final String announcementId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String content;
  final DateTime? createdAt;

  const AnnouncementComment({
    required this.id,
    required this.announcementId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'announcementId': announcementId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'content': content,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory AnnouncementComment.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return AnnouncementComment(
      id: docId,
      announcementId: (map['announcementId'] ?? '') as String,
      authorId: (map['authorId'] ?? '') as String,
      authorName: (map['authorName'] ?? 'User') as String,
      authorRole: (map['authorRole'] ?? 'Student') as String,
      content: (map['content'] ?? '') as String,
      createdAt: parsedCreatedAt,
    );
  }
}

