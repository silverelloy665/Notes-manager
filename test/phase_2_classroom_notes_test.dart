import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/classroom_note_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';

void main() {
  group('Phase 2 - Classroom Notes & Topic Map Tests', () {
    test('ClassroomNote model serialization and deserialization preserves all fields', () {
      final now = DateTime(2026, 10, 20, 14, 30);
      final note = ClassroomNote(
        id: 'note_101',
        classroomId: 'cls_123',
        unitNumber: 2,
        unitTitle: 'Unit 2: Memory Management',
        title: 'Virtual Memory & Page Replacement',
        description: 'Comprehensive slides on FIFO, LRU, and Optimal page replacement algorithms.',
        fileType: 'pdf',
        fileUrl: 'https://example.com/unit2_vm.pdf',
        fileName: 'unit2_vm.pdf',
        fileSizeBytes: 2048576,
        extractedText: 'Virtual memory separates user logical memory from physical memory...',
        status: 'published',
        allowDownload: true,
        version: 2,
        versionHistory: [
          NoteVersion(version: 1, fileName: 'unit2_vm_v1.pdf', uploadedAt: now.subtract(const Duration(days: 2)), note: 'Initial draft'),
          NoteVersion(version: 2, fileName: 'unit2_vm.pdf', uploadedAt: now, note: 'Added Belady anomaly diagrams'),
        ],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      final map = note.toMap();
      expect(map['title'], 'Virtual Memory & Page Replacement');
      expect(map['unitNumber'], 2);
      expect(map['version'], 2);
      expect(map['allowDownload'], true);
      expect(map['versionHistory'], hasLength(2));

      final restored = ClassroomNote.fromMap(map, 'note_101');
      expect(restored.id, 'note_101');
      expect(restored.unitNumber, 2);
      expect(restored.unitTitle, 'Unit 2: Memory Management');
      expect(restored.title, 'Virtual Memory & Page Replacement');
      expect(restored.version, 2);
      expect(restored.versionHistory.length, 2);
      expect(restored.versionHistory.last.note, 'Added Belady anomaly diagrams');
      expect(restored.isPublished, true);
      expect(restored.isDraft, false);
    });

    test('ClassroomNote status getters correctly evaluate published, draft, and scheduled', () {
      final now = DateTime.now();

      final publishedNote = ClassroomNote(
        id: 'n_pub',
        classroomId: 'cls_1',
        title: 'Published Note',
        status: 'published',
      );
      expect(publishedNote.isPublished, true);
      expect(publishedNote.isDraft, false);
      expect(publishedNote.isScheduled, false);

      final draftNote = ClassroomNote(
        id: 'n_draft',
        classroomId: 'cls_1',
        title: 'Draft Note',
        status: 'draft',
      );
      expect(draftNote.isPublished, false);
      expect(draftNote.isDraft, true);

      final futureScheduledNote = ClassroomNote(
        id: 'n_sched',
        classroomId: 'cls_1',
        title: 'Scheduled Note',
        status: 'published',
        scheduledPublishAt: now.add(const Duration(days: 3)),
      );
      expect(futureScheduledNote.isPublished, false);
      expect(futureScheduledNote.isScheduled, true);

      final pastScheduledNote = ClassroomNote(
        id: 'n_past_sched',
        classroomId: 'cls_1',
        title: 'Past Scheduled Note',
        status: 'published',
        scheduledPublishAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(pastScheduledNote.isPublished, true);
      expect(pastScheduledNote.isScheduled, false);
    });

    test('TopicMap integrates seamlessly with ClassroomNote', () {
      final topicMap = TopicMap(
        id: 'map_1',
        documentId: 'doc_1',
        fileName: 'os_intro.pdf',
        title: 'Introduction to Operating Systems',
        domainTopic: 'Operating Systems',
        pageCount: 15,
        totalWordCount: 4500,
        topics: [
          const TopicNode(
            id: 't_1',
            title: 'Kernel Architectures',
            pageStart: 1,
            pageEnd: 5,
            contentSnippet: 'Monolithic vs Microkernel architectures...',
            subtopics: [
              SubtopicNode(
                id: 'sub_1',
                title: 'Microkernels',
                pageNumber: 3,
                summary: 'Minimizes kernel space services to IPC and scheduling.',
                concepts: [
                  ConceptNode(name: 'Mach', description: 'Early microkernel OS', pageNumber: 3),
                ],
              ),
            ],
            wordCount: 1200,
          ),
        ],
        chunks: const [],
        createdAt: DateTime.now(),
      );

      final note = ClassroomNote(
        id: 'note_kernel',
        classroomId: 'cls_1',
        title: 'Kernel Architectures',
        topicMap: topicMap,
      );

      expect(note.topicMap, isNotNull);
      expect(note.topicMap!.topics.first.title, 'Kernel Architectures');
      expect(note.topicMap!.allSubtopics.first.title, 'Microkernels');
      expect(note.topicMap!.allConcepts.first.name, 'Mach');
    });
  });
}
