import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_exception.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = FirestoreService(firestore: fakeFirestore);
  });

  group('FirestoreService Positive Test Suite', () {
    test('TC-F-P1: Create, update, pin, and delete note in users/{uid}/notes', () async {
      const uid = 'student_user_123';

      // 1. Create note
      final note = await service.createNote(
        userId: uid,
        title: 'CPU Scheduling Algorithms',
        topic: 'Operating Systems',
        content: 'FCFS, SJF, Round Robin, Priority Scheduling',
        isPinned: false,
      );

      expect(note.id, isNotEmpty);
      expect(note.title, equals('CPU Scheduling Algorithms'));
      expect(note.isPinned, isFalse);

      // Verify in fake firestore
      final docSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .get();
      expect(docSnap.exists, isTrue);
      expect(docSnap.data()!['title'], equals('CPU Scheduling Algorithms'));

      // 2. Update note
      await service.updateNote(
        userId: uid,
        noteId: note.id,
        title: 'CPU Scheduling Algorithms (Revised)',
        topic: 'Operating Systems',
        content: 'Added Multi-level Queue Scheduling details',
        isPinned: false,
      );

      final updatedSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .get();
      expect(updatedSnap.data()!['title'], equals('CPU Scheduling Algorithms (Revised)'));

      // 3. Toggle pin
      await service.toggleNotePin(uid, note.id, false);
      final pinnedSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .get();
      expect(pinnedSnap.data()!['pinned'], isTrue);

      // 4. Delete note
      await service.deleteNote(uid, note.id);
      final deletedSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .get();
      expect(deletedSnap.exists, isFalse);
    });

    test('TC-F-P2: Classroom creation generates 6-character code and stores reservation', () async {
      const teacherId = 'teacher_456';
      const teacherName = 'Prof. Sharma';

      final classroom = await service.createClassroom(
        teacherId: teacherId,
        teacherName: teacherName,
        name: 'OS Lab Section A',
        subject: 'Operating Systems',
      );

      expect(classroom.id, isNotEmpty);
      expect(classroom.code.length, equals(6));
      expect(classroom.teacherId, equals(teacherId));
      expect(classroom.studentIds, isEmpty);

      // Check codes reservation
      final codeSnap = await fakeFirestore.collection('codes').doc(classroom.code).get();
      expect(codeSnap.exists, isTrue);
      expect(codeSnap.data()!['classroomId'], equals(classroom.id));
    });

    test('TC-F-P3: Student joins classroom with valid 6-char code', () async {
      final classroom = await service.createClassroom(
        teacherId: 'teacher_789',
        teacherName: 'Dr. Rao',
        name: 'Database Engineering',
        subject: 'Database Management',
      );

      const studentUid = 'student_999';
      final joined = await service.joinClassroom(
        studentId: studentUid,
        code: classroom.code,
      );

      expect(joined.id, equals(classroom.id));
      expect(joined.studentIds, contains(studentUid));

      final classDoc = await fakeFirestore.collection('classrooms').doc(classroom.id).get();
      final List<dynamic> enrolled = classDoc.data()!['studentIds'];
      expect(enrolled, contains(studentUid));
    });

    test('TC-F-P4: Teacher records grade for enrolled student', () async {
      final classroom = await service.createClassroom(
        teacherId: 'teacher_101',
        teacherName: 'Prof. Miller',
        name: 'Computer Networks',
        subject: 'Computer Networks',
      );

      final grade = await service.addGrade(
        classroomId: classroom.id,
        studentId: 'student_555',
        studentName: 'Aarush Mishra',
        assessmentTitle: 'Lab Quiz 1',
        maxMarks: 50.0,
        marksObtained: 46.5,
        remarks: 'Excellent network layer packet trace analysis',
      );

      expect(grade.id, isNotEmpty);
      expect(grade.percentage, closeTo(93.0, 0.1));
      expect(grade.marksObtained, equals(46.5));
      expect(grade.maxMarks, equals(50.0));

      final gradeDoc = await fakeFirestore
          .collection('classrooms')
          .doc(classroom.id)
          .collection('grades')
          .doc(grade.id)
          .get();
      expect(gradeDoc.exists, isTrue);
      expect(gradeDoc.data()!['marksObtained'], equals(46.5));
    });

    test('TC-F-P5: Teacher publishes question under questions collection', () async {
      final question = await service.createQuestion(
        topic: 'Mathematics',
        question: 'What is the characteristic equation of a square matrix?',
        answer: 'The characteristic equation is det(A - lambda*I) = 0.',
        createdBy: 'teacher_math_01',
      );

      expect(question.id, isNotEmpty);
      expect(question.topic, equals('Mathematics'));

      final qDoc = await fakeFirestore.collection('questions').doc(question.id).get();
      expect(qDoc.exists, isTrue);
      expect(qDoc.data()!['answer'], contains('det(A - lambda*I) = 0'));
    });

    test('TC-F-P6: Seed starter questions runs once and is guarded by config/seed', () async {
      await service.seedInitialQuestions();

      // Verify seed document exists
      final seedDoc = await fakeFirestore.collection('config').doc('seed').get();
      expect(seedDoc.exists, isTrue);
      expect(seedDoc.data()!['seeded'], isTrue);

      // Verify questions were added
      final qQuery = await fakeFirestore.collection('questions').get();
      expect(qQuery.docs.length, greaterThanOrEqualTo(20));

      // Call again to verify idempotency (no duplicate entries)
      await service.seedInitialQuestions();
      final qQuery2 = await fakeFirestore.collection('questions').get();
      expect(qQuery2.docs.length, equals(qQuery.docs.length));
    });

    test('TC-F-P7: Student ZIP import stores questions under users/{uid}/subjects/{subjectId}/units/{unitId}/questions', () async {
      const uid = 'student_zip_user';
      const parseResult = ZipParseResult(
        subjects: [
          ParsedSubject(
            name: 'Computer Networks',
            units: [
              ParsedUnit(
                number: 1,
                title: 'OSI Model',
                notes: [
                  ParsedFile(
                    name: 'osi.txt',
                    type: 'note',
                    fileType: 'txt',
                    relativePath: 'notes/osi.txt',
                    bytes: [1, 2, 3],
                    sizeBytes: 3,
                  ),
                ],
                practicals: [],
                questions: [
                  ParsedQuestion(
                    question: 'How many layers are in OSI?',
                    answer: '7 layers.',
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final summary = await service.saveImportedCurriculum(
        userId: uid,
        parseResult: parseResult,
        appDocumentsDirectory: '/fake/app/doc/dir',
        isReplaceMode: false,
      );

      expect(summary.subjectsCount, equals(1));
      expect(summary.unitsCount, equals(1));

      // Verify the question was stored under users/{uid}/subjects/.../units/.../questions
      final subjectsSnap = await fakeFirestore.collection('users').doc(uid).collection('subjects').get();
      final subjectDoc = subjectsSnap.docs.first;
      final unitsSnap = await subjectDoc.reference.collection('units').get();
      final unitDoc = unitsSnap.docs.first;
      final qSnap = await unitDoc.reference.collection('questions').get();

      expect(qSnap.docs.length, equals(1));
      expect(qSnap.docs.first.data()['question'], equals('How many layers are in OSI?'));

      // Verify global questions collection does NOT contain student's question
      final globalQ = await fakeFirestore.collection('questions').where('question', isEqualTo: 'How many layers are in OSI?').get();
      expect(globalQ.docs, isEmpty);
    });
  });

  group('FirestoreService Negative Test Suite', () {
    test('TC-F-N1: Joining with non-existent code throws AppException', () async {
      expect(
        () => service.joinClassroom(studentId: 'student_1', code: 'NONEX9'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('No classroom found'))),
      );
    });

    test('TC-F-N2: Duplicate join by the same student is rejected', () async {
      final classroom = await service.createClassroom(
        teacherId: 'teacher_dup',
        teacherName: 'Teacher Dup',
        name: 'Algorithms',
        subject: 'Mathematics',
      );

      const studentUid = 'student_repeat';
      await service.joinClassroom(studentId: studentUid, code: classroom.code);

      // Second join attempt must throw AppException
      expect(
        () => service.joinClassroom(studentId: studentUid, code: classroom.code),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('already enrolled'))),
      );
    });

    test('TC-F-N3: Note creation with empty title throws AppException', () async {
      expect(
        () => service.createNote(
          userId: 'student_x',
          title: '   ',
          topic: 'Operating Systems',
          content: 'Some valid content',
          isPinned: false,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('TC-F-N4: Grade marks obtained exceeding maxMarks throws AppException', () async {
      final classroom = await service.createClassroom(
        teacherId: 'teacher_marks',
        teacherName: 'Teacher Marks',
        name: 'Physics Lab',
        subject: 'Physics',
      );

      expect(
        () => service.addGrade(
          classroomId: classroom.id,
          studentId: 'student_y',
          studentName: 'Student Y',
          assessmentTitle: 'Term Exam',
          maxMarks: 50.0,
          marksObtained: 75.0, // Exceeds maxMarks!
          remarks: 'Invalid marks',
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('cannot exceed maximum marks'))),
      );
    });

    test('TC-F-N5: Subject deletion cascades and deletes all units and resources', () async {
      const uid = 'student_cascade';
      final subRef = await fakeFirestore.collection('users').doc(uid).collection('subjects').add({
        'name': 'Test Subject',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final unitRef = await subRef.collection('units').add({
        'number': 1,
        'title': 'Unit 1',
        'completed': false,
      });

      await unitRef.collection('resources').add({
        'name': 'file1.txt',
        'type': 'note',
        'fileType': 'txt',
        'relativePath': 'test.txt',
        'sizeBytes': 100,
      });

      final qRef = await unitRef.collection('questions').add({
        'topic': 'Test Subject',
        'question': 'Sample question?',
        'answer': 'Sample answer.',
      });

      await service.deleteSubject(uid, subRef.id, localSubjectPath: '/fake/test/path');

      final checkSub = await fakeFirestore.collection('users').doc(uid).collection('subjects').doc(subRef.id).get();
      expect(checkSub.exists, isFalse);

      final checkUnit = await fakeFirestore.collection('users').doc(uid).collection('subjects').doc(subRef.id).collection('units').doc(unitRef.id).get();
      expect(checkUnit.exists, isFalse);

      final checkQuestion = await fakeFirestore.collection('users').doc(uid).collection('subjects').doc(subRef.id).collection('units').doc(unitRef.id).collection('questions').doc(qRef.id).get();
      expect(checkQuestion.exists, isFalse);
    });
  });
}
