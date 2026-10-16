import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a study note created by a student in Cloud Firestore: users/{uid}/notes/{noteId}.
class Note {
  final String id;
  final String userId;
  final String title;
  final String topic;
  final String content;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.topic,
    required this.content,
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'topic': topic,
      'content': content,
      'pinned': isPinned,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, String docId, {String userId = ''}) {
    DateTime? parsedCreatedAt;
    final rawCreated = map['createdAt'] ?? map['created_at'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated);
    }

    DateTime? parsedUpdatedAt;
    final rawUpdated = map['updatedAt'] ?? map['updated_at'];
    if (rawUpdated is Timestamp) {
      parsedUpdatedAt = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated);
    }

    return Note(
      id: docId,
      userId: userId.isNotEmpty ? userId : (map['userId'] ?? map['user_id'] ?? '').toString(),
      title: (map['title'] ?? '') as String,
      topic: (map['topic'] ?? 'Other') as String,
      content: (map['content'] ?? '') as String,
      isPinned: map['pinned'] == true || map['is_pinned'] == 1 || map['is_pinned'] == true,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? topic,
    String? content,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
