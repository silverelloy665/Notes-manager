import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/note_model.dart';
import '../models/classroom_model.dart';
import '../models/grade_model.dart';
import '../models/question_model.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';

/// Central database service managing all SQLite operations, tables, and seeded records.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  /// Returns the singleton database instance, initializing if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database file and executes table definitions.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'studymate_classroom.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enforce SQLite Foreign Key constraints
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedInitialQuestions(db);
      },
    );
  }

  /// Creates all required relational tables.
  Future<void> _createTables(Database db) async {
    // 1. Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    // 2. Notes table
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        topic TEXT NOT NULL,
        content TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 3. Classrooms table
    await db.execute('''
      CREATE TABLE classrooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        code TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    // 4. Enrollments table
    await db.execute('''
      CREATE TABLE enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        classroom_id INTEGER NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        enrolled_at TEXT NOT NULL,
        UNIQUE(classroom_id, student_id)
      );
    ''');

    // 5. Grades table
    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        classroom_id INTEGER NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        assessment_title TEXT NOT NULL,
        max_marks REAL NOT NULL,
        marks_obtained REAL NOT NULL,
        remarks TEXT,
        graded_at TEXT NOT NULL
      );
    ''');

    // 6. Questions table
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT NOT NULL,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
      );
    ''');
  }

  /// Seeds initial practice questions into the database.
  Future<void> _seedInitialQuestions(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in AppConstants.seedQuestions) {
      batch.insert('questions', {
        'topic': item['topic'],
        'question': item['question'],
        'answer': item['answer'],
        'created_by': null,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ===========================================================================
  // AUTHENTICATION & SECURITY
  // ===========================================================================

  /// Generates a cryptographically secure random salt.
  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes a plaintext password combined with a salt using SHA-256.
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }

  /// Registers a new user with salted SHA-256 password hashing.
  Future<User> registerUser({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();

    // Check for existing user with identical email
    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const AppException(
        'An account with this email address already exists. Please log in or use a different email.',
      );
    }

    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    final userMap = {
      'name': name.trim(),
      'email': normalizedEmail,
      'phone': phone.trim(),
      'role': role,
      'password_hash': passwordHash,
      'salt': salt,
      'created_at': now,
    };

    final id = await db.insert('users', userMap);
    return User.fromMap({...userMap, 'id': id});
  }

  /// Authenticates a user by email and password using salted SHA-256.
  Future<User> loginUser({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (results.isEmpty) {
      throw const AppException('No registered account found with this email address.');
    }

    final userMap = results.first;
    final storedSalt = userMap['salt'] as String;
    final storedHash = userMap['password_hash'] as String;

    final computedHash = _hashPassword(password, storedSalt);
    if (computedHash != storedHash) {
      throw const AppException('Incorrect password. Please verify your credentials.');
    }

    return User.fromMap(userMap);
  }

  // ===========================================================================
  // NOTES MANAGEMENT
  // ===========================================================================

  /// Fetches notes for a specific user, sorted by pinned first, then newest updated.
  Future<List<Note>> getNotes(
    int userId, {
    String? searchQuery,
    String? topicFilter,
  }) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    final List<dynamic> whereArgs = [userId];

    if (topicFilter != null && topicFilter.isNotEmpty && topicFilter != 'All') {
      whereClause += ' AND topic = ?';
      whereArgs.add(topicFilter);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (title LIKE ? OR content LIKE ?)';
      final queryParam = '%${searchQuery.trim()}%';
      whereArgs.add(queryParam);
      whereArgs.add(queryParam);
    }

    final results = await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return results.map((map) => Note.fromMap(map)).toList();
  }

  /// Creates a new note.
  Future<Note> createNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return note.copyWith(id: id);
  }

  /// Updates an existing note.
  Future<void> updateNote(Note note) async {
    final db = await database;
    final count = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [note.id, note.userId],
    );
    if (count == 0) {
      throw const AppException('Failed to update note. Note not found.');
    }
  }

  /// Deletes a note by its ID and user ID.
  Future<void> deleteNote(int noteId, int userId) async {
    final db = await database;
    final count = await db.delete(
      'notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [noteId, userId],
    );
    if (count == 0) {
      throw const AppException('Failed to delete note. Note not found.');
    }
  }

  /// Toggles the pinned status of a note.
  Future<void> togglePinNote(int noteId, int userId, bool currentPinned) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'is_pinned': currentPinned ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [noteId, userId],
    );
  }

  // ===========================================================================
  // QUESTION BANK & PRACTICE
  // ===========================================================================

  /// Fetches practice questions, optionally filtered by academic topic.
  Future<List<Question>> getQuestions({String? topic}) async {
    final db = await database;
    List<Map<String, dynamic>> results;

    if (topic != null && topic.isNotEmpty && topic != 'All') {
      results = await db.query(
        'questions',
        where: 'topic = ?',
        whereArgs: [topic],
        orderBy: 'id ASC',
      );
    } else {
      results = await db.query('questions', orderBy: 'id ASC');
    }

    return results.map((map) => Question.fromMap(map)).toList();
  }

  /// Adds a new practice question into the question bank.
  Future<Question> addQuestion({
    required String topic,
    required String question,
    required String answer,
    required int createdBy,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final map = {
      'topic': topic,
      'question': question.trim(),
      'answer': answer.trim(),
      'created_by': createdBy,
      'created_at': now,
    };
    final id = await db.insert('questions', map);
    return Question.fromMap({...map, 'id': id});
  }

  // ===========================================================================
  // CLASSROOM MANAGEMENT (TEACHER & STUDENT)
  // ===========================================================================

  /// Generates a unique 6-character uppercase alphanumeric classroom join code.
  Future<String> _generateUniqueClassCode(Database db) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes ambiguous characters (I, O, 0, 1)
    final random = Random.secure();

    for (int attempts = 0; attempts < 50; attempts++) {
      final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      final existing = await db.query(
        'classrooms',
        where: 'code = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (existing.isEmpty) {
        return code;
      }
    }
    // Fallback timestamp-based code
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(0, 6);
  }

  /// Creates a classroom under a teacher with an auto-generated unique 6-char code.
  Future<Classroom> createClassroom({
    required int teacherId,
    required String name,
    required String subject,
  }) async {
    final db = await database;
    final code = await _generateUniqueClassCode(db);
    final now = DateTime.now().toIso8601String();

    final map = {
      'teacher_id': teacherId,
      'name': name.trim(),
      'subject': subject.trim(),
      'code': code,
      'created_at': now,
    };

    final id = await db.insert('classrooms', map);
    return Classroom.fromMap({...map, 'id': id, 'student_count': 0});
  }

  /// Fetches all classrooms created by a teacher, including enrolled student counts.
  Future<List<Classroom>> getTeacherClassrooms(int teacherId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT c.*, COUNT(e.id) AS student_count
      FROM classrooms c
      LEFT JOIN enrollments e ON c.id = e.classroom_id
      WHERE c.teacher_id = ?
      GROUP BY c.id
      ORDER BY c.created_at DESC
    ''', [teacherId]);

    return results.map((map) => Classroom.fromMap(map)).toList();
  }

  /// Enrolls a student into a classroom using a 6-character class code.
  Future<Classroom> joinClassroom({
    required int studentId,
    required String code,
  }) async {
    final db = await database;
    final normalizedCode = code.trim().toUpperCase();

    // 1. Locate classroom by code
    final classResults = await db.rawQuery('''
      SELECT c.*, u.name AS teacher_name
      FROM classrooms c
      JOIN users u ON c.teacher_id = u.id
      WHERE UPPER(c.code) = ?
      LIMIT 1
    ''', [normalizedCode]);

    if (classResults.isEmpty) {
      throw AppException(
        'No classroom found with code "$normalizedCode". Please verify the code with your teacher.',
      );
    }

    final classroomMap = classResults.first;
    final classroomId = classroomMap['id'] as int;

    // 2. Check if student is already enrolled
    final existingEnrollment = await db.query(
      'enrollments',
      where: 'classroom_id = ? AND student_id = ?',
      whereArgs: [classroomId, studentId],
      limit: 1,
    );

    if (existingEnrollment.isNotEmpty) {
      throw const AppException('You are already enrolled in this classroom.');
    }

    // 3. Insert enrollment
    final now = DateTime.now().toIso8601String();
    await db.insert('enrollments', {
      'classroom_id': classroomId,
      'student_id': studentId,
      'enrolled_at': now,
    });

    return Classroom.fromMap(classroomMap);
  }

  /// Fetches all classrooms joined by a student, with teacher name and calculated overall grade percentage.
  Future<List<Classroom>> getStudentClassrooms(int studentId) async {
    final db = await database;
    final classroomsRaw = await db.rawQuery('''
      SELECT c.*, u.name AS teacher_name
      FROM classrooms c
      JOIN enrollments e ON c.id = e.classroom_id
      JOIN users u ON c.teacher_id = u.id
      WHERE e.student_id = ?
      ORDER BY e.enrolled_at DESC
    ''', [studentId]);

    final List<Classroom> list = [];
    for (final raw in classroomsRaw) {
      final classroomId = raw['id'] as int;
      // Calculate overall grade percentage for this student in this classroom
      final grades = await getStudentGrades(classroomId, studentId);
      double? overall;
      if (grades.isNotEmpty) {
        double totalObtained = 0.0;
        double totalMax = 0.0;
        for (final g in grades) {
          totalObtained += g.marksObtained;
          totalMax += g.maxMarks;
        }
        if (totalMax > 0) {
          overall = (totalObtained / totalMax) * 100.0;
        }
      }

      list.add(Classroom.fromMap({
        ...raw,
        'overall_percentage': overall,
      }));
    }

    return list;
  }

  /// Fetches all students enrolled in a classroom with their overall grade percentage.
  Future<List<StudentGradeSummary>> getClassroomStudentsWithGrades(int classroomId) async {
    final db = await database;
    final studentsRaw = await db.rawQuery('''
      SELECT u.id AS student_id, u.name, u.email, u.phone
      FROM enrollments e
      JOIN users u ON e.student_id = u.id
      WHERE e.classroom_id = ?
      ORDER BY u.name ASC
    ''', [classroomId]);

    final List<StudentGradeSummary> list = [];
    for (final row in studentsRaw) {
      final studentId = row['student_id'] as int;
      final grades = await getStudentGrades(classroomId, studentId);

      double? overall;
      if (grades.isNotEmpty) {
        double totalObtained = 0.0;
        double totalMax = 0.0;
        for (final g in grades) {
          totalObtained += g.marksObtained;
          totalMax += g.maxMarks;
        }
        if (totalMax > 0) {
          overall = (totalObtained / totalMax) * 100.0;
        }
      }

      list.add(StudentGradeSummary(
        studentId: studentId,
        name: row['name'] as String,
        email: row['email'] as String,
        phone: row['phone'] as String,
        overallPercentage: overall,
        assessmentsCount: grades.length,
      ));
    }

    return list;
  }

  // ===========================================================================
  // GRADES MANAGEMENT
  // ===========================================================================

  /// Fetches all grades for a specific student within a classroom, newest first.
  Future<List<Grade>> getStudentGrades(int classroomId, int studentId) async {
    final db = await database;
    final results = await db.query(
      'grades',
      where: 'classroom_id = ? AND student_id = ?',
      whereArgs: [classroomId, studentId],
      orderBy: 'graded_at DESC',
    );
    return results.map((map) => Grade.fromMap(map)).toList();
  }

  /// Records a new grade for a student in a classroom.
  Future<Grade> addGrade({
    required int classroomId,
    required int studentId,
    required String assessmentTitle,
    required double maxMarks,
    required double marksObtained,
    String? remarks,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final map = {
      'classroom_id': classroomId,
      'student_id': studentId,
      'assessment_title': assessmentTitle.trim(),
      'max_marks': maxMarks,
      'marks_obtained': marksObtained,
      'remarks': (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : null,
      'graded_at': now,
    };
    final id = await db.insert('grades', map);
    return Grade.fromMap({...map, 'id': id});
  }
}

