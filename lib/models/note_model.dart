/// Represents a study note created by a student.
class Note {
  final int? id;
  final int userId;
  final String title;
  final String topic;
  final String content;
  final bool isPinned;
  final String createdAt;
  final String updatedAt;

  const Note({
    this.id,
    required this.userId,
    required this.title,
    required this.topic,
    required this.content,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'topic': topic,
      'content': content,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      topic: map['topic'] as String,
      content: map['content'] as String,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Note copyWith({
    int? id,
    int? userId,
    String? title,
    String? topic,
    String? content,
    bool? isPinned,
    String? createdAt,
    String? updatedAt,
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

