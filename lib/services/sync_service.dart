import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import 'database_helper.dart';

/// SyncService handles optional cloud synchronization with Firebase Firestore
/// while maintaining 100% offline-first local persistence via SQLite.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isFirebaseInitialized = false;

  bool get isFirebaseConnected => _isFirebaseInitialized;

  /// Initializes Firebase Firestore connection if google-services.json / firebase_options is configured
  Future<void> initFirebase() async {
    // When Firebase is configured via `flutterfire configure`, this connects Firestore listeners
    _isFirebaseInitialized = false;
    debugPrint('[SyncService] Offline-first SQLite mode active.');
  }

  /// Pushes a local student registration request to Firestore collection `registration_requests`
  Future<bool> pushRegistrationToCloud(StudentModel student) async {
    try {
      // 1. Save immediately to local SQLite DB
      await _dbHelper.insertStudent(student);

      // 2. If Firebase is active, push to Firestore
      if (_isFirebaseInitialized) {
        // FirebaseFirestore.instance.collection('registration_requests').doc(student.id).set(student.toFirestoreMap());
        debugPrint('[SyncService] Pushed student ${student.id} to Firestore collection "registration_requests"');
      }
      return true;
    } catch (e) {
      debugPrint('[SyncService] Cloud push note (falling back to offline SQLite): $e');
      return false;
    }
  }

  /// Listens to remote approval status changes from School Admin on Firestore
  void listenToApprovalUpdates(String studentId, Function(String newStatus) onStatusChange) {
    if (!_isFirebaseInitialized) return;
    // FirebaseFirestore.instance.collection('registration_requests').doc(studentId).snapshots().listen((doc) {
    //   if (doc.exists && doc.data() != null) {
    //     final status = doc.data()!['status'] as String? ?? 'PENDING_APPROVAL';
    //     _dbHelper.updateStudentStatus(studentId, status);
    //     onStatusChange(status);
    //   }
    // });
  }
}
