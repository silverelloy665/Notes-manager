import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a distinct key concept within a subtopic.
class ConceptNode {
  final String name;
  final String description;
  final int pageNumber;

  const ConceptNode({
    required this.name,
    required this.description,
    required this.pageNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'pageNumber': pageNumber,
    };
  }

  factory ConceptNode.fromMap(Map<String, dynamic> map) {
    return ConceptNode(
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      pageNumber: (map['pageNumber'] ?? 1) as int,
    );
  }
}

/// Represents a subtopic belonging to a major topic node in a document.
class SubtopicNode {
  final String id;
  final String title;
  final int pageNumber;
  final String summary;
  final List<ConceptNode> concepts;
  final List<String> keywords;

  const SubtopicNode({
    required this.id,
    required this.title,
    required this.pageNumber,
    required this.summary,
    required this.concepts,
    this.keywords = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pageNumber': pageNumber,
      'summary': summary,
      'concepts': concepts.map((c) => c.toMap()).toList(),
      'keywords': keywords,
    };
  }

  factory SubtopicNode.fromMap(Map<String, dynamic> map) {
    final rawConcepts = map['concepts'] as List? ?? [];
    final rawKeywords = map['keywords'] as List? ?? [];

    return SubtopicNode(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      pageNumber: (map['pageNumber'] ?? 1) as int,
      summary: (map['summary'] ?? '') as String,
      concepts: rawConcepts.map((c) => ConceptNode.fromMap(Map<String, dynamic>.from(c as Map))).toList(),
      keywords: rawKeywords.map((k) => k.toString()).toList(),
    );
  }
}

/// Represents a major topic / slide section in the document outline.
class TopicNode {
  final String id;
  final String title;
  final int pageStart;
  final int pageEnd;
  final String contentSnippet;
  final List<SubtopicNode> subtopics;
  final int wordCount;

  const TopicNode({
    required this.id,
    required this.title,
    required this.pageStart,
    required this.pageEnd,
    required this.contentSnippet,
    required this.subtopics,
    required this.wordCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pageStart': pageStart,
      'pageEnd': pageEnd,
      'contentSnippet': contentSnippet,
      'subtopics': subtopics.map((s) => s.toMap()).toList(),
      'wordCount': wordCount,
    };
  }

  factory TopicNode.fromMap(Map<String, dynamic> map) {
    final rawSubtopics = map['subtopics'] as List? ?? [];

    return TopicNode(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      pageStart: (map['pageStart'] ?? 1) as int,
      pageEnd: (map['pageEnd'] ?? 1) as int,
      contentSnippet: (map['contentSnippet'] ?? '') as String,
      subtopics: rawSubtopics.map((s) => SubtopicNode.fromMap(Map<String, dynamic>.from(s as Map))).toList(),
      wordCount: (map['wordCount'] ?? 0) as int,
    );
  }
}

/// Represents a semantically chunked unit of text linked to a specific topic node.
class SemanticChunk {
  final String chunkId;
  final String sourceFileName;
  final int pageNumber;
  final String topic;
  final String subtopic;
  final String content;
  final List<String> keywords;
  final int tokenCount;

  const SemanticChunk({
    required this.chunkId,
    required this.sourceFileName,
    required this.pageNumber,
    required this.topic,
    required this.subtopic,
    required this.content,
    required this.keywords,
    required this.tokenCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'chunkId': chunkId,
      'sourceFileName': sourceFileName,
      'pageNumber': pageNumber,
      'topic': topic,
      'subtopic': subtopic,
      'content': content,
      'keywords': keywords,
      'tokenCount': tokenCount,
    };
  }

  factory SemanticChunk.fromMap(Map<String, dynamic> map) {
    final rawKeywords = map['keywords'] as List? ?? [];
    return SemanticChunk(
      chunkId: (map['chunkId'] ?? '') as String,
      sourceFileName: (map['sourceFileName'] ?? '') as String,
      pageNumber: (map['pageNumber'] ?? 1) as int,
      topic: (map['topic'] ?? '') as String,
      subtopic: (map['subtopic'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      keywords: rawKeywords.map((k) => k.toString()).toList(),
      tokenCount: (map['tokenCount'] ?? 0) as int,
    );
  }
}

/// Hierarchical topic map tree of an uploaded document:
/// Document -> Topics -> Subtopics -> Concepts, with page/slide references.
class TopicMap {
  final String id;
  final String documentId;
  final String fileName;
  final String title;
  final String domainTopic;
  final int pageCount;
  final int totalWordCount;
  final List<TopicNode> topics;
  final List<SemanticChunk> chunks;
  final DateTime createdAt;

  const TopicMap({
    required this.id,
    required this.documentId,
    required this.fileName,
    required this.title,
    required this.domainTopic,
    required this.pageCount,
    required this.totalWordCount,
    required this.topics,
    required this.chunks,
    required this.createdAt,
  });

  /// Flattened list of all subtopics across all topics.
  List<SubtopicNode> get allSubtopics {
    final list = <SubtopicNode>[];
    for (final t in topics) {
      list.addAll(t.subtopics);
    }
    return list;
  }

  /// Flattened list of all concepts across all topics.
  List<ConceptNode> get allConcepts {
    final list = <ConceptNode>[];
    for (final s in allSubtopics) {
      list.addAll(s.concepts);
    }
    return list;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'fileName': fileName,
      'title': title,
      'domainTopic': domainTopic,
      'pageCount': pageCount,
      'totalWordCount': totalWordCount,
      'topics': topics.map((t) => t.toMap()).toList(),
      'chunks': chunks.map((c) => c.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TopicMap.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt = DateTime.now();
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final rawTopics = map['topics'] as List? ?? [];
    final rawChunks = map['chunks'] as List? ?? [];

    return TopicMap(
      id: docId,
      documentId: (map['documentId'] ?? '') as String,
      fileName: (map['fileName'] ?? '') as String,
      title: (map['title'] ?? 'Document') as String,
      domainTopic: (map['domainTopic'] ?? 'Other') as String,
      pageCount: (map['pageCount'] ?? 1) as int,
      totalWordCount: (map['totalWordCount'] ?? 0) as int,
      topics: rawTopics.map((t) => TopicNode.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
      chunks: rawChunks.map((c) => SemanticChunk.fromMap(Map<String, dynamic>.from(c as Map))).toList(),
      createdAt: parsedCreatedAt,
    );
  }
}

