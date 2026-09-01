import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/student_model.dart';
import '../models/email_queue_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _dbName = 'al_ijadah_pickup.db';
  static const int _dbVersion = 1;

  // Persistent storage keys for Web PWA & browser local storage
  static const String _prefStudentsKey = 'pwa_persisted_students_v1';
  static const String _prefEmailQueueKey = 'pwa_persisted_email_queue_v1';

  // In-memory cached repository across Web browsers and mobile
  static final List<StudentModel> _inMemoryStudents = [];
  static final List<EmailQueueItem> _inMemoryEmailQueue = [];
  static bool _isInMemorySeeded = false;
  static int _nextEmailQueueId = 1;

  DatabaseFactory get _dbFactory {
    if (kIsWeb) {
      return databaseFactoryFfiWebNoWebWorker;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<Database?> get database async {
    if (kIsWeb) {
      _ensureInMemorySeeded();
      return null;
    }
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database;
    } catch (e) {
      debugPrint('[DatabaseHelper] Native DB init note (using in-memory fallback): $e');
      _ensureInMemorySeeded();
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final factory = _dbFactory;

    String dbPath;
    if (kIsWeb) {
      dbPath = _dbName;
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      dbPath = p.join(documentsDirectory.path, _dbName);
    }

    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    // One-time cleanup of legacy demo students so existing devices also get a clean slate
    await _cleanupDemoStudentsIfPresent(db);

    return db;
  }

  Future<void> _cleanupDemoStudentsIfPresent(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purged = prefs.getBool('demo_students_purged') ?? false;
      if (!purged) {
        await db.delete(
          'students',
          where: 'id IN (?, ?, ?)',
          whereArgs: ['AIS-2026-1082', 'AIS-2026-2194', 'AIS-2026-3351'],
        );
        await prefs.setBool('demo_students_purged', true);
        debugPrint('[DatabaseHelper] Cleaned legacy demo students for pristine out-of-the-box state.');
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Note on demo cleanup: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Students Table
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grade TEXT NOT NULL,
        supervisor TEXT NOT NULL,
        parent_email TEXT NOT NULL,
        parent_mobile TEXT NOT NULL,
        guardian_name TEXT NOT NULL,
        photo_path TEXT,
        status TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. Email Queue Table (Offline-first Direct SMTP Queue)
    await db.execute('''
      CREATE TABLE email_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_email TEXT NOT NULL,
        parent_mobile TEXT NOT NULL,
        student_name TEXT NOT NULL,
        guardian_name TEXT NOT NULL,
        pickup_timestamp TEXT NOT NULL,
        is_sent INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Fresh install out of the box starts with completely clean slate (no dummy students)
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Schema upgrades if any in future versions
  }

  Future<void> init() async {
    await _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    if (_isInMemorySeeded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_prefStudentsKey);
      if (studentsJson != null && studentsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(studentsJson) as List<dynamic>;
        _inMemoryStudents.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _inMemoryStudents.add(StudentModel.fromSqliteMap(item));
          }
        }
        debugPrint('[DatabaseHelper] Loaded ${_inMemoryStudents.length} student(s) from persistent storage.');
      }

      final emailQueueJson = prefs.getString(_prefEmailQueueKey);
      if (emailQueueJson != null && emailQueueJson.isNotEmpty) {
        final List<dynamic> decodedQueue = jsonDecode(emailQueueJson) as List<dynamic>;
        _inMemoryEmailQueue.clear();
        for (final item in decodedQueue) {
          if (item is Map<String, dynamic>) {
            _inMemoryEmailQueue.add(EmailQueueItem.fromSqliteMap(item));
          }
        }
        if (_inMemoryEmailQueue.isNotEmpty) {
          _nextEmailQueueId = _inMemoryEmailQueue.map((e) => e.id ?? 0).fold(0, (max, v) => v > max ? v : max) + 1;
        }
        debugPrint('[DatabaseHelper] Loaded ${_inMemoryEmailQueue.length} email queue item(s) from persistent storage.');
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Error loading persisted data: $e');
    } finally {
      _isInMemorySeeded = true;
    }
  }

  Future<void> _saveStudentsToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inMemoryStudents.map((s) => s.toSqliteMap()).toList();
      await prefs.setString(_prefStudentsKey, jsonEncode(list));
      debugPrint('[DatabaseHelper] Persisted ${_inMemoryStudents.length} student(s) to local storage.');
    } catch (e) {
      debugPrint('[DatabaseHelper] Error persisting students: $e');
    }
  }

  Future<void> _saveEmailQueueToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inMemoryEmailQueue.map((e) => e.toSqliteMap()).toList();
      await prefs.setString(_prefEmailQueueKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[DatabaseHelper] Error persisting email queue: $e');
    }
  }

  void _ensureInMemorySeeded() {
    if (_isInMemorySeeded) return;
    _isInMemorySeeded = true;
    _loadFromPreferences();
  }

  // ===================== STUDENTS CRUD =====================

  Future<int> insertStudent(StudentModel student) async {
    _ensureInMemorySeeded();
    _inMemoryStudents.removeWhere((s) => s.id == student.id);
    _inMemoryStudents.insert(0, student);
    await _saveStudentsToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.insert(
            'students',
            student.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (_) {}
    }
    return 1;
  }

  Future<int> updateStudent(StudentModel student) async {
    _ensureInMemorySeeded();
    final index = _inMemoryStudents.indexWhere((s) => s.id == student.id);
    if (index >= 0) {
      _inMemoryStudents[index] = student;
    } else {
      _inMemoryStudents.add(student);
    }
    await _saveStudentsToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.update(
            'students',
            student.toSqliteMap(),
            where: 'id = ?',
            whereArgs: [student.id],
          );
        }
      } catch (_) {}
    }
    return 1;
  }

  Future<StudentModel?> getStudentById(String id) async {
    if (!_isInMemorySeeded) {
      await _loadFromPreferences();
    }
    final found = _inMemoryStudents.where((s) => s.id == id).toList();
    if (found.isNotEmpty) return found.first;

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          final maps = await db.query(
            'students',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (maps.isNotEmpty) {
            return StudentModel.fromSqliteMap(maps.first);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<StudentModel>> getAllStudents() async {
    if (!_isInMemorySeeded) {
      await _loadFromPreferences();
    }
    if (kIsWeb) {
      return List<StudentModel>.from(_inMemoryStudents);
    }

    try {
      final db = await database;
      if (db != null) {
        final maps = await db.query('students', orderBy: 'updated_at DESC');
        if (maps.isNotEmpty) {
          return maps.map((map) => StudentModel.fromSqliteMap(map)).toList();
        }
      }
    } catch (_) {}

    return List<StudentModel>.from(_inMemoryStudents);
  }

  Future<int> updateStudentStatus(String id, String status) async {
    _ensureInMemorySeeded();
    final index = _inMemoryStudents.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _inMemoryStudents[index] = _inMemoryStudents[index].copyWith(
        status: status,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    await _saveStudentsToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.update(
            'students',
            {
              'status': status,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (_) {}
    }
    return 1;
  }

  Future<int> deleteStudent(String id) async {
    _ensureInMemorySeeded();
    _inMemoryStudents.removeWhere((s) => s.id == id);
    await _saveStudentsToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.delete(
            'students',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (_) {}
    }
    return 1;
  }

  // ===================== EMAIL QUEUE OPERATIONS =====================

  Future<int> queueEmail(EmailQueueItem item) async {
    _ensureInMemorySeeded();
    final assignedId = item.id ?? _nextEmailQueueId++;
    final assignedItem = item.copyWith(id: assignedId);
    _inMemoryEmailQueue.add(assignedItem);
    await _saveEmailQueueToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.insert('email_queue', item.toSqliteMap());
        }
      } catch (_) {}
    }
    return assignedId;
  }

  Future<List<EmailQueueItem>> getPendingEmails() async {
    if (!_isInMemorySeeded) {
      await _loadFromPreferences();
    }
    if (kIsWeb) {
      return _inMemoryEmailQueue.where((i) => !i.sent).toList();
    }

    try {
      final db = await database;
      if (db != null) {
        final maps = await db.query(
          'email_queue',
          where: 'is_sent = 0',
          orderBy: 'id ASC',
        );
        return maps.map((map) => EmailQueueItem.fromSqliteMap(map)).toList();
      }
    } catch (_) {}

    return _inMemoryEmailQueue.where((i) => !i.sent).toList();
  }

  Future<List<EmailQueueItem>> getAllQueueItems() async {
    if (!_isInMemorySeeded) {
      await _loadFromPreferences();
    }
    if (kIsWeb) {
      return List<EmailQueueItem>.from(_inMemoryEmailQueue.reversed);
    }

    try {
      final db = await database;
      if (db != null) {
        final maps = await db.query(
          'email_queue',
          orderBy: 'id DESC',
        );
        return maps.map((map) => EmailQueueItem.fromSqliteMap(map)).toList();
      }
    } catch (_) {}

    return List<EmailQueueItem>.from(_inMemoryEmailQueue.reversed);
  }

  Future<int> markEmailSent(int id) async {
    _ensureInMemorySeeded();
    final index = _inMemoryEmailQueue.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _inMemoryEmailQueue[index] = _inMemoryEmailQueue[index].copyWith(isSent: 1);
    }
    await _saveEmailQueueToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          return await db.update(
            'email_queue',
            {'is_sent': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (_) {}
    }
    return 1;
  }

  Future<int> getPendingQueueCount() async {
    if (!_isInMemorySeeded) {
      await _loadFromPreferences();
    }
    if (kIsWeb) {
      return _inMemoryEmailQueue.where((i) => !i.sent).length;
    }

    try {
      final db = await database;
      if (db != null) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM email_queue WHERE is_sent = 0');
        return Sqflite.firstIntValue(result) ?? 0;
      }
    } catch (_) {}

    return _inMemoryEmailQueue.where((i) => !i.sent).length;
  }

  Future<void> clearDatabaseAndReseed() async {
    _isInMemorySeeded = true;
    _inMemoryStudents.clear();
    _inMemoryEmailQueue.clear();
    await _saveStudentsToPreferences();
    await _saveEmailQueueToPreferences();

    if (!kIsWeb) {
      try {
        final db = await database;
        if (db != null) {
          await db.delete('students');
          await db.delete('email_queue');
        }
      } catch (_) {}
    }
  }
}
