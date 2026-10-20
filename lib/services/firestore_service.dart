import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:path/path.dart' as p;
import 'package:studymate_classroom/models/announcement_model.dart';
import 'package:studymate_classroom/models/assignment_model.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/classroom_note_model.dart';
import 'package:studymate_classroom/models/coverage_report_model.dart';
import 'package:studymate_classroom/models/exam_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/models/live_class_model.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/models/summary_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/utils/app_exception.dart';
import 'package:studymate_classroom/utils/validators.dart';

/// Centralized data access service managing Firebase Authentication and Cloud Firestore.
/// Enforces single-responsibility repository patterns, offline cache detection, and chunked batch writes.
class FirestoreService {
  final FirebaseFirestore _firestore;
  final fb_auth.FirebaseAuth? _auth;

  FirestoreService({
    FirebaseFirestore? firestore,
    fb_auth.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        // ignore: prefer_initializing_formals
        _auth = auth;

  fb_auth.FirebaseAuth get _authInstance => _auth ?? fb_auth.FirebaseAuth.instance;

  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= FirestoreService();

  /// For unit testing with fake_cloud_firestore
  static void setMockInstance(FirestoreService service) {
    _instance = service;
  }

  // ===========================================================================
  // 1. AUTHENTICATION & USER PROFILE
  // ===========================================================================

  /// Stream of current authenticated Firebase user.
  Stream<fb_auth.User?> get authStateChanges => _authInstance.authStateChanges();

  /// Current user UID or null if not signed in.
  String? get currentUid {
    try {
      return _authInstance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the profile for the currently signed-in user.
  Future<User?> getCurrentUserProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    return getUserProfile(uid);
  }

  /// Fetches a user document from `users/{uid}`.
  Future<User?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return User.fromMap(doc.data()!, uid);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to load user profile: $e');
    }
  }

  /// Registers a new user with Firebase Auth and creates `users/{uid}` in Firestore.
  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String password,
  }) async {
    final nameErr = Validators.validateName(name);
    if (nameErr != null) throw AppException(nameErr);
    final emailErr = Validators.validateEmail(email);
    if (emailErr != null) throw AppException(emailErr);
    final phoneErr = Validators.validatePhone(phone);
    if (phoneErr != null) throw AppException(phoneErr);
    final passErr = Validators.validatePassword(password);
    if (passErr != null) throw AppException(passErr);

    try {
      final credential = await _authInstance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      final user = User(
        id: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(user.toMap());
      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Registration failed: $e');
    }
  }

  /// Authenticates with email and password and loads the user role from Firestore.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final emailErr = Validators.validateEmail(email);
    if (emailErr != null) throw AppException(emailErr);
    final passErr = Validators.validateRequired(password, 'Password');
    if (passErr != null) throw AppException(passErr);

    try {
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final user = await getUserProfile(uid);
      if (user == null) {
        throw const AppException(
          'User record not found in database. Please contact support.',
        );
      }
      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Login failed: $e');
    }
  }

  /// Signs out of Firebase.
  Future<void> logout() async {
    try {
      await _authInstance.signOut();
    } catch (e) {
      throw AppException('Failed to sign out: $e');
    }
  }

  // ===========================================================================
  // 2. STUDENT NOTES (users/{uid}/notes/{noteId})
  // ===========================================================================

  /// Live stream of notes for a student, ordered by pinned descending and createdAt descending.
  Stream<({List<Note> notes, bool isFromCache})> getNotesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notes')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final notes = snapshot.docs.map((doc) => Note.fromMap(doc.data(), doc.id, userId: userId)).toList();

      // In-memory sort fallback ensures pinned appear first even if index is building
      notes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return (notes: notes, isFromCache: isFromCache);
    });
  }

  /// Creates a note in `users/{uid}/notes`.
  Future<Note> createNote({
    required String userId,
    required String title,
    required String topic,
    required String content,
    bool isPinned = false,
  }) async {
    final titleErr = Validators.validateRequired(title, 'Title');
    if (titleErr != null) throw AppException(titleErr);
    final contentErr = Validators.validateRequired(content, 'Content');
    if (contentErr != null) throw AppException(contentErr);

    try {
      final docRef = _firestore.collection('users').doc(userId).collection('notes').doc();
      final note = Note(
        id: docRef.id,
        userId: userId,
        title: title.trim(),
        topic: topic,
        content: content.trim(),
        isPinned: isPinned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(note.toMap());
      return note;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to create note: $e');
    }
  }

  /// Updates a note in `users/{uid}/notes/{noteId}`.
  Future<void> updateNote({
    required String userId,
    required String noteId,
    required String title,
    required String topic,
    required String content,
    required bool isPinned,
  }) async {
    final titleErr = Validators.validateRequired(title, 'Title');
    if (titleErr != null) throw AppException(titleErr);
    final contentErr = Validators.validateRequired(content, 'Content');
    if (contentErr != null) throw AppException(contentErr);

    try {
      await _firestore.collection('users').doc(userId).collection('notes').doc(noteId).update({
        'title': title.trim(),
        'topic': topic,
        'content': content.trim(),
        'pinned': isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update note: $e');
    }
  }

  /// Toggles pinned status for a note.
  Future<void> toggleNotePin(String userId, String noteId, bool currentPinState) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notes').doc(noteId).update({
        'pinned': !currentPinState,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to toggle pin: $e');
    }
  }

  /// Deletes a note.
  Future<void> deleteNote(String userId, String noteId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notes').doc(noteId).delete();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete note: $e');
    }
  }

  // ===========================================================================
  // 3. CLASSROOMS & ENROLLMENT (classrooms/{classId}, codes/{code})
  // ===========================================================================

  /// Live stream of classrooms owned by a teacher.
  Stream<({List<Classroom> classrooms, bool isFromCache})> getTeacherClassroomsStream(String teacherId) {
    return _firestore
        .collection('classrooms')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Classroom.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return (classrooms: list, isFromCache: isFromCache);
    });
  }

  /// Live stream of classrooms joined by a student.
  Stream<({List<Classroom> classrooms, bool isFromCache})> getStudentClassroomsStream(String studentId) {
    return _firestore
        .collection('classrooms')
        .where('studentIds', arrayContains: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Classroom.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return (classrooms: list, isFromCache: isFromCache);
    });
  }

  /// Creates a classroom with a unique 6-character code guaranteed by a transaction on `codes/{code}`.
  Future<Classroom> createClassroom({
    required String teacherId,
    required String teacherName,
    required String name,
    required String subject,
  }) async {
    final nameErr = Validators.validateRequired(name, 'Classroom Name');
    if (nameErr != null) throw AppException(nameErr);
    final subjectErr = Validators.validateRequired(subject, 'Subject');
    if (subjectErr != null) throw AppException(subjectErr);

    try {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final random = Random.secure();

      // Retry loop to obtain a unique 6-character code via transaction
      for (int attempt = 0; attempt < 10; attempt++) {
        final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
        final codeDocRef = _firestore.collection('codes').doc(code);
        final classDocRef = _firestore.collection('classrooms').doc();

        final success = await _firestore.runTransaction<bool>((transaction) async {
          final codeSnapshot = await transaction.get(codeDocRef);
          if (codeSnapshot.exists) {
            return false; // Code collision, retry
          }

          final newClassroom = Classroom(
            id: classDocRef.id,
            teacherId: teacherId,
            teacherName: teacherName,
            name: name.trim(),
            subject: subject.trim(),
            code: code,
            studentIds: const [],
            createdAt: DateTime.now(),
          );

          transaction.set(classDocRef, newClassroom.toMap());
          transaction.set(codeDocRef, {
            'classroomId': classDocRef.id,
            'teacherId': teacherId,
            'code': code,
            'createdAt': FieldValue.serverTimestamp(),
          });

          return true;
        });

        if (success) {
          return Classroom(
            id: classDocRef.id,
            teacherId: teacherId,
            teacherName: teacherName,
            name: name.trim(),
            subject: subject.trim(),
            code: code,
            studentIds: const [],
            createdAt: DateTime.now(),
          );
        }
      }

      throw const AppException('Failed to generate a unique classroom code. Please try again.');
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to create classroom: $e');
    }
  }

  /// Student joins a classroom by entering a 6-character code.
  /// Uses a transaction to verify code existence and reject duplicate join.
  Future<Classroom> joinClassroom({
    required String studentId,
    required String code,
  }) async {
    final codeErr = Validators.validateClassCode(code);
    if (codeErr != null) throw AppException(codeErr);

    final cleanCode = code.trim().toUpperCase();

    try {
      final codeDoc = await _firestore.collection('codes').doc(cleanCode).get();
      if (!codeDoc.exists || codeDoc.data() == null) {
        throw AppException('No classroom found with code "$cleanCode".');
      }

      final classroomId = codeDoc.data()!['classroomId'] as String;
      final classDocRef = _firestore.collection('classrooms').doc(classroomId);

      return await _firestore.runTransaction<Classroom>((transaction) async {
        final classSnapshot = await transaction.get(classDocRef);
        if (!classSnapshot.exists || classSnapshot.data() == null) {
          throw AppException('Classroom record for code "$cleanCode" no longer exists.');
        }

        final data = classSnapshot.data()!;
        final isJoiningEnabled = (data['isJoiningEnabled'] ?? true) as bool;
        if (!isJoiningEnabled) {
          throw const AppException('Joining this classroom is currently disabled by the instructor.');
        }

        final currentStudents = List<String>.from(data['studentIds'] ?? []);
        if (currentStudents.contains(studentId)) {
          throw const AppException('You are already enrolled in this classroom.');
        }

        final requireApproval = (data['requireApproval'] ?? false) as bool;
        final pendingStudents = List<String>.from(data['pendingStudentIds'] ?? []);

        if (requireApproval) {
          if (pendingStudents.contains(studentId)) {
            throw const AppException('Your join request is already pending instructor approval.');
          }
          pendingStudents.add(studentId);
          transaction.update(classDocRef, {'pendingStudentIds': pendingStudents});
          data['pendingStudentIds'] = pendingStudents;
          return Classroom.fromMap(data, classSnapshot.id);
        }

        currentStudents.add(studentId);
        transaction.update(classDocRef, {'studentIds': currentStudents});

        data['studentIds'] = currentStudents;
        return Classroom.fromMap(data, classSnapshot.id);
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to join classroom: $e');
    }
  }

  /// Updates classroom settings (name, subject, description, join toggle, approval mode, archive).
  Future<void> updateClassroomSettings(
    String classroomId, {
    String? name,
    String? subject,
    String? description,
    bool? isJoiningEnabled,
    bool? requireApproval,
    bool? isArchived,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
      if (subject != null && subject.trim().isNotEmpty) updates['subject'] = subject.trim();
      if (description != null) updates['description'] = description.trim();
      if (isJoiningEnabled != null) updates['isJoiningEnabled'] = isJoiningEnabled;
      if (requireApproval != null) updates['requireApproval'] = requireApproval;
      if (isArchived != null) updates['isArchived'] = isArchived;

      if (updates.isNotEmpty) {
        await _firestore.collection('classrooms').doc(classroomId).update(updates);
      }
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update classroom settings: $e');
    }
  }

  /// Regenerates a classroom's 6-character code atomically, freeing the old code doc.
  Future<String> regenerateClassroomCode({
    required String classroomId,
    required String oldCode,
    required String teacherId,
  }) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final newCode = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      final newCodeDocRef = _firestore.collection('codes').doc(newCode);
      final oldCodeDocRef = _firestore.collection('codes').doc(oldCode);
      final classDocRef = _firestore.collection('classrooms').doc(classroomId);

      try {
        final success = await _firestore.runTransaction<bool>((transaction) async {
          final snapshot = await transaction.get(newCodeDocRef);
          if (snapshot.exists) return false;

          transaction.delete(oldCodeDocRef);
          transaction.set(newCodeDocRef, {
            'classroomId': classroomId,
            'teacherId': teacherId,
            'code': newCode,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(classDocRef, {'code': newCode});
          return true;
        });

        if (success) return newCode;
      } catch (e) {
        // Retry loop
      }
    }
    throw const AppException('Failed to regenerate a unique classroom code. Please try again.');
  }

  /// Removes a student from a classroom roster.
  Future<void> removeStudentFromClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to remove student: $e');
    }
  }

  /// Approves a student from pending requests into the enrolled students roster.
  Future<void> approveStudent({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'pendingStudentIds': FieldValue.arrayRemove([studentId]),
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to approve student: $e');
    }
  }

  /// Rejects a pending join request.
  Future<void> rejectPendingStudent({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'pendingStudentIds': FieldValue.arrayRemove([studentId]),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to reject student request: $e');
    }
  }

  /// Deletes a classroom and releases its reserved join code.
  Future<void> deleteClassroom({
    required String classroomId,
    required String code,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('classrooms').doc(classroomId));
      batch.delete(_firestore.collection('codes').doc(code));
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete classroom: $e');
    }
  }

  /// Live stream of announcements posted in a classroom stream.
  Stream<List<Announcement>> getAnnouncementsStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('announcements')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Announcement.fromMap(doc.data(), doc.id)).toList();
      // Pinned announcements first, then descending by createdAt
      list.sort((a, b) {
        if (a.pinned != b.pinned) {
          return a.pinned ? -1 : 1;
        }
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Posts a new announcement to the classroom stream.
  Future<Announcement> postAnnouncement({
    required String classroomId,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String content,
    List<AnnouncementAttachment> attachments = const [],
    bool pinned = false,
  }) async {
    if (content.trim().isEmpty && attachments.isEmpty) {
      throw const AppException('Announcement cannot be completely empty.');
    }

    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('announcements').doc();
      final announcement = Announcement(
        id: docRef.id,
        classroomId: classroomId,
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        content: content.trim(),
        attachments: attachments,
        pinned: pinned,
        commentCount: 0,
        createdAt: DateTime.now(),
      );

      await docRef.set(announcement.toMap());
      return announcement;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to post announcement: $e');
    }
  }

  /// Deletes an announcement from the classroom stream.
  Future<void> deleteAnnouncement(String classroomId, String announcementId) async {
    try {
      await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('announcements')
          .doc(announcementId)
          .delete();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete announcement: $e');
    }
  }

  /// Toggles pinned status for an announcement.
  Future<void> togglePinAnnouncement(String classroomId, String announcementId, bool currentPinned) async {
    try {
      await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('announcements')
          .doc(announcementId)
          .update({'pinned': !currentPinned});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update announcement: $e');
    }
  }

  /// Live stream of comments on an announcement.
  Stream<List<AnnouncementComment>> getCommentsStream(String classroomId, String announcementId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('announcements')
        .doc(announcementId)
        .collection('comments')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => AnnouncementComment.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  /// Adds a comment to an announcement and increments commentCount.
  Future<AnnouncementComment> addComment({
    required String classroomId,
    required String announcementId,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      throw const AppException('Comment cannot be empty.');
    }

    try {
      final annDocRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('announcements')
          .doc(announcementId);

      final commentDocRef = annDocRef.collection('comments').doc();

      final comment = AnnouncementComment(
        id: commentDocRef.id,
        announcementId: announcementId,
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        content: content.trim(),
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(commentDocRef, comment.toMap());
      batch.update(annDocRef, {'commentCount': FieldValue.increment(1)});
      await batch.commit();

      return comment;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to add comment: $e');
    }
  }

  /// Deletes a comment from an announcement and decrements commentCount.
  Future<void> deleteComment(String classroomId, String announcementId, String commentId) async {
    try {
      final annDocRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('announcements')
          .doc(announcementId);

      final batch = _firestore.batch();
      batch.delete(annDocRef.collection('comments').doc(commentId));
      batch.update(annDocRef, {'commentCount': FieldValue.increment(-1)});
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete comment: $e');
    }
  }

  // ===========================================================================
  // 3B. CLASSROOM NOTES & TOPIC MAPS (classrooms/{classId}/notes/{noteId})
  // ===========================================================================

  /// Live stream of notes published or drafted in a classroom.
  Stream<List<ClassroomNote>> getClassroomNotesStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('notes')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ClassroomNote.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) {
        if (a.unitNumber != b.unitNumber) {
          return a.unitNumber.compareTo(b.unitNumber);
        }
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Uploads and parses a new classroom note with topic map, text, and summaries.
  Future<ClassroomNote> uploadClassroomNote({
    required String classroomId,
    required int unitNumber,
    required String unitTitle,
    required String title,
    String? description,
    required String fileType,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    String extractedText = '',
    TopicMap? topicMap,
    MultiLevelSummary? summary,
    String status = 'published',
    DateTime? scheduledPublishAt,
    bool allowDownload = true,
  }) async {
    if (title.trim().isEmpty) {
      throw const AppException('Note title cannot be empty.');
    }

    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('notes').doc();
      final now = DateTime.now();

      final initialVersion = NoteVersion(
        version: 1,
        fileName: fileName ?? title,
        uploadedAt: now,
        note: 'Initial upload',
      );

      final note = ClassroomNote(
        id: docRef.id,
        classroomId: classroomId,
        unitNumber: unitNumber,
        unitTitle: unitTitle,
        title: title.trim(),
        description: description?.trim(),
        fileType: fileType,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        extractedText: extractedText,
        topicMap: topicMap,
        summary: summary,
        status: status,
        scheduledPublishAt: scheduledPublishAt,
        allowDownload: allowDownload,
        version: 1,
        versionHistory: [initialVersion],
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(note.toMap());
      return note;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to upload classroom note: $e');
    }
  }

  /// Re-uploads a new file version of an existing note while maintaining question links and history.
  Future<void> reuploadClassroomNoteVersion({
    required String classroomId,
    required String noteId,
    required String fileName,
    required String fileType,
    required String extractedText,
    TopicMap? topicMap,
    MultiLevelSummary? summary,
    int? fileSizeBytes,
    String? noteRemark,
  }) async {
    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('notes').doc(noteId);
      final snapshot = await docRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw const AppException('Note does not exist.');
      }

      final existingNote = ClassroomNote.fromMap(snapshot.data()!, noteId);
      final newVersionNum = existingNote.version + 1;
      final newVersion = NoteVersion(
        version: newVersionNum,
        fileName: fileName,
        uploadedAt: DateTime.now(),
        note: noteRemark ?? 'Version $newVersionNum re-upload',
      );

      final updatedHistory = [...existingNote.versionHistory, newVersion];

      await docRef.update({
        'version': newVersionNum,
        'fileName': fileName,
        'fileType': fileType,
        'extractedText': extractedText,
        'topicMap': topicMap?.toMap(),
        'summary': summary?.toMap(),
        'fileSizeBytes': fileSizeBytes,
        'versionHistory': updatedHistory.map((v) => v.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update note version: $e');
    }
  }

  /// Updates note metadata, unit, visibility, or download settings.
  Future<void> updateClassroomNote(
    String classroomId,
    String noteId, {
    String? title,
    String? description,
    int? unitNumber,
    String? unitTitle,
    String? status,
    DateTime? scheduledPublishAt,
    bool? allowDownload,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (title != null) updates['title'] = title.trim();
      if (description != null) updates['description'] = description.trim();
      if (unitNumber != null) updates['unitNumber'] = unitNumber;
      if (unitTitle != null) updates['unitTitle'] = unitTitle;
      if (status != null) updates['status'] = status;
      if (scheduledPublishAt != null) updates['scheduledPublishAt'] = Timestamp.fromDate(scheduledPublishAt);
      if (allowDownload != null) updates['allowDownload'] = allowDownload;

      await _firestore.collection('classrooms').doc(classroomId).collection('notes').doc(noteId).update(updates);
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update classroom note: $e');
    }
  }

  /// Deletes a classroom note.
  Future<void> deleteClassroomNote(String classroomId, String noteId) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).collection('notes').doc(noteId).delete();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete classroom note: $e');
    }
  }

  // ===========================================================================
  // 3B. CLASSROOM QUESTION BANK (classrooms/{classId}/questions/{questionId})
  // ===========================================================================

  /// Live stream of questions in a classroom's question bank.
  Stream<({List<Question> questions, bool isFromCache})> getClassroomQuestionsStream(
    String classroomId, {
    String? topic,
    int? unitNumber,
    String? questionType,
    String? difficulty,
  }) {
    Query query = _firestore.collection('classrooms').doc(classroomId).collection('questions');

    if (topic != null && topic.isNotEmpty && topic != 'All Topics') {
      query = query.where('topic', isEqualTo: topic);
    }
    if (unitNumber != null) {
      query = query.where('unitNumber', isEqualTo: unitNumber);
    }
    if (questionType != null && questionType.isNotEmpty && questionType != 'all') {
      query = query.where('questionType', isEqualTo: questionType);
    }
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'All') {
      query = query.where('difficulty', isEqualTo: difficulty);
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Question.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return (questions: list, isFromCache: isFromCache);
    });
  }

  /// Creates a single question in a classroom's question bank.
  Future<Question> createClassroomQuestion(String classroomId, Question question) async {
    try {
      final colRef = _firestore.collection('classrooms').doc(classroomId).collection('questions');
      final docRef = question.id.isNotEmpty && question.id != 'new' ? colRef.doc(question.id) : colRef.doc();
      final q = question.copyWith(id: docRef.id, classroomId: classroomId, createdAt: DateTime.now());
      await docRef.set(q.toMap());
      return q;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to create classroom question: $e');
    }
  }

  /// Updates an existing question in a classroom's question bank.
  Future<void> updateClassroomQuestion(String classroomId, Question question) async {
    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('questions').doc(question.id);
      await docRef.update(question.toMap());
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update classroom question: $e');
    }
  }

  /// Deletes a question from a classroom's question bank.
  Future<void> deleteClassroomQuestion(String classroomId, String questionId) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).collection('questions').doc(questionId).delete();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete classroom question: $e');
    }
  }

  /// Batches multiple questions into the classroom question bank.
  Future<List<Question>> batchAddClassroomQuestions(String classroomId, List<Question> questions) async {
    if (questions.isEmpty) return [];
    try {
      final createdList = <Question>[];
      final colRef = _firestore.collection('classrooms').doc(classroomId).collection('questions');

      const chunkSize = 400;
      for (int i = 0; i < questions.length; i += chunkSize) {
        final end = (i + chunkSize < questions.length) ? i + chunkSize : questions.length;
        final chunk = questions.sublist(i, end);
        final batch = _firestore.batch();

        for (final q in chunk) {
          final docRef = q.id.isNotEmpty && q.id != 'new' ? colRef.doc(q.id) : colRef.doc();
          final populatedQ = q.copyWith(
            id: docRef.id,
            classroomId: classroomId,
            createdAt: q.createdAt ?? DateTime.now(),
          );
          batch.set(docRef, populatedQ.toMap());
          createdList.add(populatedQ);
        }
        await batch.commit();
      }
      return createdList;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to batch add classroom questions: $e');
    }
  }

  // ===========================================================================
  // 3C. CLASSROOM EXAMS & ASSESSMENTS (classrooms/{classId}/exams/{examId})
  // ===========================================================================

  /// Live stream of exams in a classroom.
  Stream<({List<Exam> exams, bool isFromCache})> getClassroomExamsStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('exams')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs
          .map((doc) => Exam.fromMap(doc.data(), doc.id, classroomId: classroomId))
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return (exams: list, isFromCache: isFromCache);
    });
  }

  /// Creates a timed classroom exam.
  Future<Exam> createClassroomExam(String classroomId, Exam exam) async {
    try {
      final colRef = _firestore.collection('classrooms').doc(classroomId).collection('exams');
      final docRef = exam.id.isNotEmpty && exam.id != 'new' ? colRef.doc(exam.id) : colRef.doc();
      final populated = exam.copyWith(
        id: docRef.id,
        classroomId: classroomId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await docRef.set(populated.toMap());
      return populated;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to create classroom exam: $e');
    }
  }

  /// Updates an existing classroom exam.
  Future<void> updateClassroomExam(String classroomId, Exam exam) async {
    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('exams').doc(exam.id);
      await docRef.update(exam.toMap());
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update classroom exam: $e');
    }
  }

  /// Deletes a classroom exam and its subcollections.
  Future<void> deleteClassroomExam(String classroomId, String examId) async {
    try {
      final examRef = _firestore.collection('classrooms').doc(classroomId).collection('exams').doc(examId);
      final subs = await examRef.collection('submissions').get();
      final batch = _firestore.batch();
      for (final doc in subs.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(examRef);
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete classroom exam: $e');
    }
  }

  /// Live stream of submissions for a specific exam.
  Stream<List<ExamSubmission>> getExamSubmissionsStream(String classroomId, String examId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('exams')
        .doc(examId)
        .collection('submissions')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ExamSubmission.fromMap(doc.data(), doc.id, classroomId: classroomId, examId: examId))
          .toList();
    });
  }

  /// Gets single submission for a student.
  Future<ExamSubmission?> getStudentExamSubmission(String classroomId, String examId, String studentId) async {
    try {
      final doc = await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('exams')
          .doc(examId)
          .collection('submissions')
          .doc(studentId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return ExamSubmission.fromMap(doc.data()!, doc.id, classroomId: classroomId, examId: examId);
    } catch (e) {
      return null;
    }
  }

  /// Saves or auto-saves student's ongoing or final exam submission.
  Future<void> saveExamSubmission(String classroomId, String examId, ExamSubmission submission) async {
    try {
      final docRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('exams')
          .doc(examId)
          .collection('submissions')
          .doc(submission.studentId);
      await docRef.set(submission.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to save exam submission: $e');
    }
  }

  /// Updates score release setting across exam and submissions.
  Future<void> releaseExamScores(String classroomId, String examId, bool release) async {
    try {
      final examRef = _firestore.collection('classrooms').doc(classroomId).collection('exams').doc(examId);
      await examRef.update({'releaseScoresImmediately': release});

      final subs = await examRef.collection('submissions').get();
      final batch = _firestore.batch();
      for (final doc in subs.docs) {
        batch.update(doc.reference, {'status': release ? 'released' : 'graded'});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to release exam scores: $e');
    }
  }

  // ===========================================================================
  // 3D. CLASSROOM ASSIGNMENTS & PROJECTS (classrooms/{classId}/assignments/{id})
  // ===========================================================================

  /// Live stream of assignments in a classroom.
  Stream<({List<Assignment> assignments, bool isFromCache})> getClassroomAssignmentsStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('assignments')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data(), doc.id, classroomId: classroomId))
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return (assignments: list, isFromCache: isFromCache);
    });
  }

  /// Creates a classroom assignment.
  Future<Assignment> createClassroomAssignment(String classroomId, Assignment assignment) async {
    try {
      final colRef = _firestore.collection('classrooms').doc(classroomId).collection('assignments');
      final docRef = assignment.id.isNotEmpty && assignment.id != 'new' ? colRef.doc(assignment.id) : colRef.doc();
      final populated = assignment.copyWith(
        id: docRef.id,
        classroomId: classroomId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await docRef.set(populated.toMap());
      return populated;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to create classroom assignment: $e');
    }
  }

  /// Updates an assignment.
  Future<void> updateClassroomAssignment(String classroomId, Assignment assignment) async {
    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('assignments').doc(assignment.id);
      await docRef.update(assignment.toMap());
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update classroom assignment: $e');
    }
  }

  /// Deletes an assignment.
  Future<void> deleteClassroomAssignment(String classroomId, String assignmentId) async {
    try {
      final assignRef = _firestore.collection('classrooms').doc(classroomId).collection('assignments').doc(assignmentId);
      final subs = await assignRef.collection('submissions').get();
      final batch = _firestore.batch();
      for (final doc in subs.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(assignRef);
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete classroom assignment: $e');
    }
  }

  /// Live stream of submissions for an assignment.
  Stream<List<AssignmentSubmission>> getAssignmentSubmissionsStream(String classroomId, String assignmentId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), doc.id, classroomId: classroomId, assignmentId: assignmentId))
          .toList();
    });
  }

  /// Gets single submission of a student.
  Future<AssignmentSubmission?> getStudentAssignmentSubmission(String classroomId, String assignmentId, String studentId) async {
    try {
      final doc = await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .doc(studentId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return AssignmentSubmission.fromMap(doc.data()!, doc.id, classroomId: classroomId, assignmentId: assignmentId);
    } catch (e) {
      return null;
    }
  }

  /// Submits student work for an assignment.
  Future<void> submitAssignment(String classroomId, String assignmentId, AssignmentSubmission submission) async {
    try {
      final docRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .doc(submission.studentId);
      await docRef.set(submission.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to submit assignment: $e');
    }
  }

  /// Unsubmits student work so they can revise before grading.
  Future<void> unsubmitAssignment(String classroomId, String assignmentId, String studentId) async {
    try {
      final docRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .doc(studentId);
      await docRef.update({'status': 'assigned', 'submittedAt': null});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to unsubmit assignment: $e');
    }
  }

  /// Grades a student submission with rubric points and feedback.
  Future<void> gradeAssignmentSubmission(
    String classroomId,
    String assignmentId,
    String submissionId, {
    required double points,
    required Map<String, double> rubricScores,
    required String feedback,
    String? gradedBy,
  }) async {
    try {
      final docRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .doc(submissionId);
      await docRef.update({
        'pointsAwarded': points,
        'rubricScores': rubricScores,
        'feedback': feedback,
        'status': 'graded',
        'gradedAt': FieldValue.serverTimestamp(),
        if (gradedBy != null) 'gradedBy': gradedBy,
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to grade assignment: $e');
    }
  }

  // ===========================================================================
  // 3E. LIVE CLASSES & MEETINGS (classrooms/{classId}/live_classes/{id})
  // ===========================================================================

  /// Live stream of live classes in a classroom.
  Stream<({List<LiveClassSession> sessions, bool isFromCache})> getLiveClassesStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('live_classes')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs
          .map((doc) => LiveClassSession.fromMap(doc.data(), doc.id, classroomId: classroomId))
          .toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return (sessions: list, isFromCache: isFromCache);
    });
  }

  /// Starts a live class session and auto-posts an announcement to the classroom stream.
  Future<LiveClassSession> startLiveClassSession(
    String classroomId,
    LiveClassSession session, {
    bool autoPostAnnouncement = true,
  }) async {
    try {
      final colRef = _firestore.collection('classrooms').doc(classroomId).collection('live_classes');
      final docRef = session.id.isNotEmpty && session.id != 'new' ? colRef.doc(session.id) : colRef.doc();
      final populated = session.copyWith(
        id: docRef.id,
        classroomId: classroomId,
        startedAt: DateTime.now(),
        isOngoing: true,
      );
      await docRef.set(populated.toMap());

      if (autoPostAnnouncement) {
        await postAnnouncement(
          classroomId: classroomId,
          authorId: session.hostTeacherId,
          authorName: session.hostTeacherName,
          authorRole: 'Teacher',
          content: '🔴 Live Class Started: "${session.title}". Tap below to join the meeting room.',
          pinned: true,
          attachments: [
            AnnouncementAttachment(
              name: 'Join Live Class Room',
              url: session.meetUrl,
              type: 'link',
            ),
          ],
        );
      }

      return populated;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to start live class: $e');
    }
  }

  /// Ends a live class session.
  Future<void> endLiveClassSession(String classroomId, String sessionId, {String? notes}) async {
    try {
      final updates = <String, dynamic>{
        'isOngoing': false,
        'endedAt': FieldValue.serverTimestamp(),
      };
      if (notes != null && notes.isNotEmpty) {
        updates['notes'] = notes;
      }
      await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('live_classes')
          .doc(sessionId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to end live class: $e');
    }
  }

  /// Records student attendance for a live class session.
  Future<void> recordLiveClassAttendance(
    String classroomId,
    String sessionId,
    StudentAttendanceRecord record,
  ) async {
    try {
      final docRef = _firestore
          .collection('classrooms')
          .doc(classroomId)
          .collection('live_classes')
          .doc(sessionId);
      await docRef.update({
        'attendanceRecords.${record.studentId}': record.toMap(),
      });
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      // Non-blocking for silent attendance logging
    }
  }

  // ===========================================================================
  // 4. ASSESSMENT GRADES (classrooms/{classId}/grades/{gradeId})
  // ===========================================================================

  /// Live stream of grades awarded to a student in a classroom.
  Stream<({List<Grade> grades, bool isFromCache})> getStudentGradesStream(String classroomId, String studentId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('grades')
        .where('studentId', isEqualTo: studentId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Grade.fromMap(doc.data(), doc.id, classroomId: classroomId)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return (grades: list, isFromCache: isFromCache);
    });
  }

  /// Live stream of all grades in a classroom.
  Stream<({List<Grade> grades, bool isFromCache})> getClassroomGradesStream(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('grades')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Grade.fromMap(doc.data(), doc.id, classroomId: classroomId)).toList();
      return (grades: list, isFromCache: isFromCache);
    });
  }

  /// Adds a new grade assessment for a student.
  Future<Grade> addGrade({
    required String classroomId,
    required String studentId,
    required String studentName,
    required String assessmentTitle,
    required double maxMarks,
    required double marksObtained,
    String? remarks,
  }) async {
    final titleErr = Validators.validateRequired(assessmentTitle, 'Assessment Title');
    if (titleErr != null) throw AppException(titleErr);
    final maxErr = Validators.validateMaxMarks(maxMarks.toString());
    if (maxErr != null) throw AppException(maxErr);
    final marksErr = Validators.validateMarksObtained(marksObtained.toString(), maxMarks);
    if (marksErr != null) throw AppException(marksErr);

    try {
      final docRef = _firestore.collection('classrooms').doc(classroomId).collection('grades').doc();
      final grade = Grade(
        id: docRef.id,
        classroomId: classroomId,
        studentId: studentId,
        studentName: studentName,
        assessmentTitle: assessmentTitle.trim(),
        maxMarks: maxMarks,
        marksObtained: marksObtained,
        remarks: remarks?.trim().isEmpty == true ? null : remarks?.trim(),
        createdAt: DateTime.now(),
      );

      await docRef.set(grade.toMap());
      return grade;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to add grade: $e');
    }
  }

  /// Computes student grade summaries for a classroom roster.
  Future<List<StudentGradeSummary>> getStudentSummaries(String classroomId, List<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    try {
      // 1. Fetch all student profiles
      final List<User> students = [];
      for (final uid in studentIds) {
        final profile = await getUserProfile(uid);
        if (profile != null) {
          students.add(profile);
        } else {
          students.add(User(
            id: uid,
            name: 'Student ($uid)',
            email: 'Unknown',
            phone: 'Unknown',
            role: 'Student',
          ));
        }
      }

      // 2. Fetch all grades in classroom
      final gradesSnapshot = await _firestore.collection('classrooms').doc(classroomId).collection('grades').get();
      final grades = gradesSnapshot.docs.map((d) => Grade.fromMap(d.data(), d.id, classroomId: classroomId)).toList();

      // 3. Aggregate scores per student
      final Map<String, List<Grade>> gradesByStudent = {};
      for (final g in grades) {
        gradesByStudent.putIfAbsent(g.studentId, () => []).add(g);
      }

      return students.map((student) {
        final studentGrades = gradesByStudent[student.id] ?? [];
        final totalObtained = studentGrades.fold(0.0, (acc, g) => acc + g.marksObtained);
        final totalMax = studentGrades.fold(0.0, (acc, g) => acc + g.maxMarks);

        return StudentGradeSummary(
          studentId: student.id,
          studentName: student.name,
          studentEmail: student.email,
          studentPhone: student.phone,
          totalObtained: totalObtained,
          totalMax: totalMax,
          assessmentsCount: studentGrades.length,
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to calculate student summaries: $e');
    }
  }

  // ===========================================================================
  // 5. PRACTICE QUESTIONS (questions/{questionId})
  // ===========================================================================

  /// Live stream of questions, optionally filtered by academic topic.
  /// Live stream of questions, optionally filtered by academic topic and student.
  /// Combines global questions with student-owned questions generated from notes/PDFs.
  Stream<({List<Question> questions, bool isFromCache})> getQuestionsStream({String? topic, String? userId}) {
    final uid = userId ?? currentUid;
    Query globalQuery = _firestore.collection('questions');
    if (topic != null && topic != 'All Topics') {
      globalQuery = globalQuery.where('topic', isEqualTo: topic);
    }

    if (uid == null) {
      return globalQuery.snapshots(includeMetadataChanges: true).map((snapshot) {
        final isFromCache = snapshot.metadata.isFromCache;
        final list = snapshot.docs.map((doc) => Question.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        return (questions: list, isFromCache: isFromCache);
      });
    }

    Query userQuery = _firestore.collection('users').doc(uid).collection('questions');
    if (topic != null && topic != 'All Topics') {
      userQuery = userQuery.where('topic', isEqualTo: topic);
    }

    return globalQuery.snapshots(includeMetadataChanges: true).asyncMap((globalSnap) async {
      final isFromCache = globalSnap.metadata.isFromCache;
      final globalList = globalSnap.docs.map((doc) => Question.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

      List<Question> userList = [];
      try {
        final userSnap = await userQuery.get();
        userList = userSnap.docs.map((doc) => Question.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      } catch (_) {}

      final seen = <String>{};
      final combined = <Question>[];
      for (final q in [...userList, ...globalList]) {
        final key = '${q.topic}::${q.question}'.toLowerCase().trim();
        if (seen.add(key)) {
          combined.add(q);
        }
      }
      return (questions: combined, isFromCache: isFromCache);
    });
  }

  /// Creates a practice question in the global question bank.
  Future<Question> createQuestion({
    required String topic,
    required String question,
    required String answer,
    required String createdBy,
    String? subjectId,
    String? unitId,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
  }) async {
    final qErr = Validators.validateRequired(question, 'Question');
    if (qErr != null) throw AppException(qErr);
    final aErr = Validators.validateRequired(answer, 'Answer');
    if (aErr != null) throw AppException(aErr);

    try {
      final docRef = _firestore.collection('questions').doc();
      final q = Question(
        id: docRef.id,
        topic: topic,
        question: question.trim(),
        answer: answer.trim(),
        createdBy: createdBy,
        subjectId: subjectId,
        unitId: unitId,
        createdAt: DateTime.now(),
        options: options,
        correctOptionIndex: correctOptionIndex,
        explanation: explanation,
      );

      await docRef.set(q.toMap());
      return q;
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to create question: $e');
    }
  }

  /// Batch creates multiple practice questions in Cloud Firestore.
  /// Saves to user-owned storage to ensure students can always generate questions,
  /// with automatic fallback so permission errors never block question generation.
  Future<List<Question>> createQuestionsBatch({
    required List<({
      String topic,
      String question,
      String answer,
      String? subjectId,
      String? unitId,
      List<String>? options,
      int? correctOptionIndex,
      String? explanation,
    })> questions,
    required String createdBy,
  }) async {
    if (questions.isEmpty) return [];

    final List<Question> createdList = [];
    final uid = createdBy.isNotEmpty ? createdBy : (currentUid ?? 'student');

    // 1. Save to user-owned subcollection: users/{uid}/questions
    // Unconditionally permitted by Firestore security rules for students.
    try {
      final userBatch = _firestore.batch();
      for (final q in questions) {
        final docRef = _firestore.collection('users').doc(uid).collection('questions').doc();
        final questionObj = Question(
          id: docRef.id,
          topic: q.topic,
          question: q.question.trim(),
          answer: q.answer.trim(),
          createdBy: uid,
          subjectId: q.subjectId,
          unitId: q.unitId,
          createdAt: DateTime.now(),
          options: q.options,
          correctOptionIndex: q.correctOptionIndex,
          explanation: q.explanation,
        );
        userBatch.set(docRef, questionObj.toMap());
        createdList.add(questionObj);
      }
      await userBatch.commit();
    } catch (_) {}

    // 2. Also try global questions collection
    try {
      final globalBatch = _firestore.batch();
      for (final q in questions) {
        final docRef = _firestore.collection('questions').doc();
        final questionObj = Question(
          id: docRef.id,
          topic: q.topic,
          question: q.question.trim(),
          answer: q.answer.trim(),
          createdBy: uid,
          subjectId: q.subjectId,
          unitId: q.unitId,
          createdAt: DateTime.now(),
          options: q.options,
          correctOptionIndex: q.correctOptionIndex,
          explanation: q.explanation,
        );
        globalBatch.set(docRef, questionObj.toMap());
        if (createdList.isEmpty) {
          createdList.add(questionObj);
        }
      }
      await globalBatch.commit();
    } catch (e) {
      if (createdList.isNotEmpty) {
        return createdList;
      }
      if (e is FirebaseException) {
        throw AppException.fromFirebase(e);
      }
      throw AppException('Failed to batch create questions: $e');
    }

    return createdList;
  }

  /// Saves a complete batch of Question model objects with full grounding metadata.
  Future<List<Question>> saveQuestionsFullBatch({
    required List<Question> questions,
    required String createdBy,
  }) async {
    if (questions.isEmpty) return [];

    final List<Question> createdList = [];
    final uid = createdBy.isNotEmpty ? createdBy : (currentUid ?? 'student');

    // 1. Save to user-owned subcollection
    try {
      final userBatch = _firestore.batch();
      for (final q in questions) {
        final docRef = q.id.isNotEmpty
            ? _firestore.collection('users').doc(uid).collection('questions').doc(q.id)
            : _firestore.collection('users').doc(uid).collection('questions').doc();

        final qWithId = q.id.isEmpty
            ? q.copyWith(id: docRef.id, createdBy: uid)
            : q;

        userBatch.set(docRef, qWithId.toMap());
        createdList.add(qWithId);
      }
      await userBatch.commit();
    } catch (_) {}

    // 2. Also save to global collection
    try {
      final globalBatch = _firestore.batch();
      for (final q in (createdList.isNotEmpty ? createdList : questions)) {
        final docRef = _firestore.collection('questions').doc(q.id);
        globalBatch.set(docRef, q.toMap());
      }
      await globalBatch.commit();
    } catch (_) {}

    return createdList.isNotEmpty ? createdList : questions;
  }

  /// Saves a hierarchical TopicMap for a processed document under users/{uid}/topic_maps.
  Future<void> saveTopicMap(String userId, TopicMap topicMap) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_maps')
          .doc(topicMap.id)
          .set(topicMap.toMap());
    } catch (_) {}
  }

  /// Retrieves a TopicMap by ID for a user.
  Future<TopicMap?> getTopicMap(String userId, String topicMapId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_maps')
          .doc(topicMapId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return TopicMap.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Live stream of all TopicMaps for an uploaded document or user.
  Stream<List<TopicMap>> getTopicMapsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('topic_maps')
        .snapshots()
        .map((snap) => snap.docs.map((d) => TopicMap.fromMap(d.data(), d.id)).toList());
  }

  /// Updates Spaced Repetition (SM-2) stats for a practiced question.
  Future<void> updateQuestionSrs(String userId, String questionId, {
    required int srsInterval,
    required int srsRepetitions,
    required double srsEaseFactor,
    required DateTime nextReviewDate,
    required double lastScore,
  }) async {
    try {
      final updateData = {
        'srsInterval': srsInterval,
        'srsRepetitions': srsRepetitions,
        'srsEaseFactor': srsEaseFactor,
        'nextReviewDate': Timestamp.fromDate(nextReviewDate),
        'lastScore': lastScore,
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('questions')
          .doc(questionId)
          .update(updateData);

      // Also try to update global question if exists
      try {
        await _firestore.collection('questions').doc(questionId).update(updateData);
      } catch (_) {}
    } catch (_) {}
  }

  /// Saves a verified CoverageReport for a document under users/{uid}/coverage_reports.
  Future<void> saveCoverageReport(String userId, CoverageReport report) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('coverage_reports')
          .doc(report.documentId)
          .set(report.toMap());
    } catch (_) {}
  }

  /// Retrieves a saved CoverageReport for a specific document.
  Future<CoverageReport?> getCoverageReport(String userId, String documentId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('coverage_reports')
          .doc(documentId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return CoverageReport.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Searches for an existing TopicMap by its file SHA-256 hash to prevent duplicate parsing on re-upload.
  Future<TopicMap?> findTopicMapByHash(String userId, String fileHash) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_maps')
          .where('fileHash', isEqualTo: fileHash)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return TopicMap.fromMap(doc.data(), doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Removes previously generated questions for a document to enable clean regeneration.
  Future<void> deleteQuestionsByDocumentId(String userId, String documentId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('questions')
          .where('documentId', isEqualTo: documentId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Submits student feedback or flags a low-quality question.
  Future<void> reportQuestion({
    required String questionId,
    required String reason,
    required String reportedBy,
    String? notes,
  }) async {
    try {
      await _firestore.collection('question_reports').add({
        'questionId': questionId,
        'reason': reason,
        'reportedBy': reportedBy,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'reportedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Seeds 20 foundational questions once, guarded by `config/seed`. Never duplicates.
  /// Starter questions are attributed to the seeding teacher or provided teacherId.
  Future<void> seedInitialQuestions([String? teacherId]) async {
    try {
      final seedDocRef = _firestore.collection('config').doc('seed');
      final seedDoc = await seedDocRef.get();
      if (seedDoc.exists) return; // Already seeded

      final authorId = teacherId ?? currentUid ?? 'system_teacher';

      final batch = _firestore.batch();
      for (final seed in AppConstants.initialQuestions) {
        final qRef = _firestore.collection('questions').doc();
        batch.set(qRef, {
          'topic': seed.topic,
          'question': seed.question,
          'answer': seed.answer,
          'createdBy': authorId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(seedDocRef, {
        'seeded': true,
        'count': AppConstants.initialQuestions.length,
        'seededBy': authorId,
        'seededAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      // Ignored if offline or already seeded
    }
  }

  // ===========================================================================
  // 6. SUBJECT MATERIAL LIBRARY (users/{uid}/subjects/.../units/.../resources)
  // ===========================================================================

  /// Live stream of subjects for a student.
  Stream<({List<Subject> subjects, bool isFromCache})> getSubjectsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
      final isFromCache = snapshot.metadata.isFromCache;
      final List<Subject> result = [];

      for (final doc in snapshot.docs) {
        final unitsSnapshot = await doc.reference.collection('units').get();
        final totalUnits = unitsSnapshot.docs.length;
        final completedUnits = unitsSnapshot.docs.where((u) => u.data()['completed'] == true).length;
        result.add(Subject.fromMap(doc.data(), doc.id, totalUnits: totalUnits, completedUnits: completedUnits));
      }

      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return (subjects: result, isFromCache: isFromCache);
    });
  }

  /// Live stream of units for a subject.
  Stream<({List<Unit> units, bool isFromCache})> getUnitsStream(String userId, String subjectId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('units')
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
      final isFromCache = snapshot.metadata.isFromCache;
      final List<Unit> result = [];

      for (final doc in snapshot.docs) {
        final resSnapshot = await doc.reference.collection('resources').get();
        final notesCount = resSnapshot.docs.where((r) => r.data()['type'] == 'note').length;
        final practicalsCount = resSnapshot.docs.where((r) => r.data()['type'] == 'practical').length;
        final qSnapshot = await doc.reference.collection('questions').get();
        final questionsCount = qSnapshot.docs.length;

        result.add(Unit.fromMap(
          doc.data(),
          doc.id,
          subjectId: subjectId,
          notesCount: notesCount,
          practicalsCount: practicalsCount,
          questionsCount: questionsCount,
        ));
      }

      result.sort((a, b) => a.number.compareTo(b.number));
      return (units: result, isFromCache: isFromCache);
    });
  }

  /// Live stream of student-owned practice questions imported for a unit:
  /// users/{userId}/subjects/{subjectId}/units/{unitId}/questions
  Stream<({List<Question> questions, bool isFromCache})> getUnitQuestionsStream(
    String userId,
    String subjectId,
    String unitId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('units')
        .doc(unitId)
        .collection('questions')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
      return (questions: list, isFromCache: isFromCache);
    });
  }

  /// Live stream of resources for a unit.
  Stream<({List<ResourceItem> resources, bool isFromCache})> getResourcesStream(
    String userId,
    String subjectId,
    String unitId, {
    String? type,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('units')
        .doc(unitId)
        .collection('resources');

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final isFromCache = snapshot.metadata.isFromCache;
      final list = snapshot.docs
          .map((doc) => ResourceItem.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
                subjectId: subjectId,
                unitId: unitId,
              ))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return (resources: list, isFromCache: isFromCache);
    });
  }

  /// Toggles a unit's completion status.
  Future<void> setUnitCompleted(String userId, String subjectId, String unitId, bool completed) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .update({'completed': completed});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to update unit completion: $e');
    }
  }

  /// Renames a subject.
  Future<void> renameSubject(String userId, String subjectId, String newName) async {
    final err = Validators.validateSubjectName(newName);
    if (err != null) throw AppException(err);

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .update({'name': newName.trim()});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to rename subject: $e');
    }
  }

  /// Renames a unit.
  Future<void> renameUnit(String userId, String subjectId, String unitId, String newTitle) async {
    final err = Validators.validateUnitTitle(newTitle);
    if (err != null) throw AppException(err);

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .update({'title': newTitle.trim()});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to rename unit: $e');
    }
  }

  /// Renames a resource.
  Future<void> renameResource(String userId, String subjectId, String unitId, String resourceId, String newName) async {
    final err = Validators.validateRequired(newName, 'Resource Name');
    if (err != null) throw AppException(err);

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .collection('resources')
          .doc(resourceId)
          .update({'name': newName.trim()});
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to rename file: $e');
    }
  }

  /// Deletes a resource: removes document from Firestore and deletes local file from disk.
  Future<void> deleteResource(
    String userId,
    String subjectId,
    String unitId,
    String resourceId, {
    required String localFilePath,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .collection('resources')
          .doc(resourceId)
          .delete();

      final file = File(localFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete resource: $e');
    }
  }

  /// Deletes a unit: removes all child resources and questions in chunked batches, deletes unit document,
  /// and removes the local directory on disk.
  Future<void> deleteUnit(
    String userId,
    String subjectId,
    String unitId, {
    required String localUnitPath,
  }) async {
    try {
      final unitRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId);

      final resources = await unitRef.collection('resources').get();
      final questions = await unitRef.collection('questions').get();
      await _commitBatchedDeletions([
        ...resources.docs.map((d) => d.reference),
        ...questions.docs.map((d) => d.reference),
      ]);
      await unitRef.delete();

      final dir = Directory(localUnitPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete unit: $e');
    }
  }

  /// Deletes a subject: cascades deletion of all child units, resources, and questions in chunked batches (<500 ops),
  /// deletes subject document, and removes local directory on disk.
  Future<void> deleteSubject(
    String userId,
    String subjectId, {
    required String localSubjectPath,
  }) async {
    try {
      final subjectRef = _firestore.collection('users').doc(userId).collection('subjects').doc(subjectId);
      final unitsSnapshot = await subjectRef.collection('units').get();

      final List<DocumentReference> refsToDelete = [];
      for (final unitDoc in unitsSnapshot.docs) {
        final resSnapshot = await unitDoc.reference.collection('resources').get();
        refsToDelete.addAll(resSnapshot.docs.map((r) => r.reference));
        final qSnapshot = await unitDoc.reference.collection('questions').get();
        refsToDelete.addAll(qSnapshot.docs.map((r) => r.reference));
        refsToDelete.add(unitDoc.reference);
      }
      refsToDelete.add(subjectRef);

      await _commitBatchedDeletions(refsToDelete);

      final dir = Directory(localSubjectPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      throw AppException('Failed to delete subject: $e');
    }
  }

  /// Commits document deletions in chunked batches (<= 450 per batch) to respect Firestore 500 ops limit.
  Future<void> _commitBatchedDeletions(List<DocumentReference> refs) async {
    const chunkSize = 450;
    for (int i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize < refs.length) ? i + chunkSize : refs.length;
      final batch = _firestore.batch();
      for (int j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }

  /// Commits parsed ZIP study material to local disk and Firestore in chunked batches.
  Future<({int subjectsCount, int unitsCount, int notesCount, int practicalsCount, int skippedCount})> saveImportedCurriculum({
    required String userId,
    required ZipParseResult parseResult,
    required String appDocumentsDirectory,
    required bool isReplaceMode,
  }) async {
    int importedSubjects = 0;
    int importedUnits = 0;
    int importedNotes = 0;
    int importedPracticals = 0;
    int skippedFiles = parseResult.skippedFiles.length;

    try {
      final libraryBaseDir = Directory(p.join(appDocumentsDirectory, 'library', userId));
      if (!await libraryBaseDir.exists()) {
        await libraryBaseDir.create(recursive: true);
      }

      final subjectsColRef = _firestore.collection('users').doc(userId).collection('subjects');

      for (final subject in parseResult.subjects) {
        // 1. Check if subject exists
        final existingSubjectQuery = await subjectsColRef.where('name', isEqualTo: subject.name).limit(1).get();

        DocumentReference subjectRef;
        if (existingSubjectQuery.docs.isNotEmpty) {
          subjectRef = existingSubjectQuery.docs.first.reference;
          if (isReplaceMode) {
            // Delete existing units and resources first
            final units = await subjectRef.collection('units').get();
            final List<DocumentReference> toDelete = [];
            for (final u in units.docs) {
              final res = await u.reference.collection('resources').get();
              toDelete.addAll(res.docs.map((r) => r.reference));
              final qs = await u.reference.collection('questions').get();
              toDelete.addAll(qs.docs.map((r) => r.reference));
              toDelete.add(u.reference);
            }
            await _commitBatchedDeletions(toDelete);
          }
        } else {
          subjectRef = subjectsColRef.doc();
          await subjectRef.set({
            'name': subject.name,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        importedSubjects++;

        // 2. Process Units
        for (final unit in subject.units) {
          final existingUnitQuery = await subjectRef
              .collection('units')
              .where('number', isEqualTo: unit.number)
              .limit(1)
              .get();

          DocumentReference unitRef;
          if (existingUnitQuery.docs.isNotEmpty) {
            unitRef = existingUnitQuery.docs.first.reference;
            await unitRef.update({'title': unit.title});
          } else {
            unitRef = subjectRef.collection('units').doc();
            await unitRef.set({
              'number': unit.number,
              'title': unit.title,
              'completed': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          importedUnits++;

          // Prepare batch for resources in this unit
          WriteBatch batch = _firestore.batch();
          int batchCount = 0;

          Future<void> flushBatch() async {
            if (batchCount > 0) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
            }
          }

          // 3. Process Notes & Practicals
          final allFiles = [...unit.notes, ...unit.practicals];
          for (final file in allFiles) {
            final targetDiskPath = p.join(
              libraryBaseDir.path,
              subject.name,
              'Unit ${unit.number}',
              file.type == 'practical' ? 'practicals' : 'notes',
              file.name,
            );

            final targetFile = File(targetDiskPath);

            // In merge mode, skip if file already exists
            if (!isReplaceMode && await targetFile.exists()) {
              skippedFiles++;
              continue;
            }

            // Write to disk
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(file.bytes, flush: true);

            // Add Firestore resource document
            final resRef = unitRef.collection('resources').doc();
            batch.set(resRef, {
              'name': file.name,
              'type': file.type,
              'fileType': file.fileType,
              'relativePath': file.relativePath,
              'sizeBytes': file.sizeBytes,
              'createdAt': FieldValue.serverTimestamp(),
            });
            batchCount++;

            if (file.type == 'practical') {
              importedPracticals++;
            } else {
              importedNotes++;
            }

            if (batchCount >= 400) {
              await flushBatch();
            }
          }

          // 4. Process Unit Questions (if questions.json was present)
          // Saved to student-owned subcollection:
          // users/{uid}/subjects/{subjectId}/units/{unitId}/questions
          for (final q in unit.questions) {
            final qRef = unitRef.collection('questions').doc();
            batch.set(qRef, {
              'topic': subject.name,
              'question': q.question,
              'answer': q.answer,
              'unitNumber': unit.number,
              'createdAt': FieldValue.serverTimestamp(),
            });
            batchCount++;

            if (batchCount >= 400) {
              await flushBatch();
            }
          }

          await flushBatch();
        }
      }

      return (
        subjectsCount: importedSubjects,
        unitsCount: importedUnits,
        notesCount: importedNotes,
        practicalsCount: importedPracticals,
        skippedCount: skippedFiles,
      );
    } on FirebaseException catch (e) {
      throw AppException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to commit imported study material: $e');
    }
  }
}
