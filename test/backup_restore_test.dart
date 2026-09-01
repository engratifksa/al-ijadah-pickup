import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_ijadah_pickup/config/app_config.dart';
import 'package:al_ijadah_pickup/models/student_model.dart';
import 'package:al_ijadah_pickup/services/database_helper.dart';
import 'package:al_ijadah_pickup/services/backup_restore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Platform Backup & Restore Service Tests', () {
    final dbHelper = DatabaseHelper();
    final backupService = BackupRestoreService();

    setUp(() async {
      await dbHelper.clearDatabaseAndReseed();
    });

    test('generateBackupJson produces valid structured JSON with metadata & checksum', () async {
      // Add a test student
      final student = StudentModel(
        id: 'AIS-2026-7777',
        name: 'Tariq Al-Harbi',
        grade: 'Grade 2 - Emerald',
        supervisor: 'Ustadh Omar',
        parentEmail: 'parent.tariq@example.com',
        parentMobile: '+966 50 111 2233',
        guardianName: 'Abdullah Al-Harbi',
        status: 'APPROVED',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await dbHelper.insertStudent(student);

      final jsonStr = await backupService.generateBackupJson();
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['app'], equals('Al Ijadah Smart Pickup'));
      expect(decoded['version'], equals('1.0.0'));
      expect(decoded['studentCount'], equals(1));
      expect(decoded.containsKey('checksum'), isTrue);
      expect(decoded.containsKey('settings'), isTrue);

      final studentsList = decoded['students'] as List<dynamic>;
      expect(studentsList.length, equals(1));
      expect(studentsList.first['id'], equals('AIS-2026-7777'));
      expect(studentsList.first['name'], equals('Tariq Al-Harbi'));
    });

    test('restoreFromParsedData merges new records without deleting existing', () async {
      // Existing student
      final existingStudent = StudentModel(
        id: 'AIS-2026-0001',
        name: 'Existing Student A',
        grade: 'KG 1',
        supervisor: 'Supervisor A',
        parentEmail: 'parent.a@example.com',
        parentMobile: '+966 55 111 1111',
        guardianName: 'Guardian A',
        status: 'APPROVED',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await dbHelper.insertStudent(existingStudent);

      // Incoming backup payload with 2 students (one new, one updated)
      final backupPayload = {
        'app': 'Al Ijadah Smart Pickup',
        'version': '1.0.0',
        'exportDate': 'Monday, 01 Sept 2026',
        'students': [
          {
            'id': 'AIS-2026-0002',
            'name': 'Imported Student B',
            'grade': 'Grade 5',
            'supervisor': 'Supervisor B',
            'parent_email': 'parent.b@example.com',
            'parent_mobile': '+966 55 222 2222',
            'guardian_name': 'Guardian B',
            'status': 'APPROVED',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        ],
        'settings': {
          'school_phone': '+966 55 596 2300',
        },
      };

      final result = await backupService.restoreFromParsedData(backupPayload, replaceAll: false);

      expect(result.success, isTrue);
      expect(result.studentsRestored, equals(1));

      final allStudents = await dbHelper.getAllStudents();
      expect(allStudents.length, equals(2));
      expect(allStudents.any((s) => s.id == 'AIS-2026-0001'), isTrue);
      expect(allStudents.any((s) => s.id == 'AIS-2026-0002'), isTrue);
    });

    test('restoreFromParsedData with replaceAll=true wipes existing roster cleanly', () async {
      // Existing student
      final existingStudent = StudentModel(
        id: 'AIS-2026-OLD',
        name: 'Old Device Student',
        grade: 'KG 1',
        supervisor: 'Supervisor',
        parentEmail: 'old@example.com',
        parentMobile: '+966 55 000 0000',
        guardianName: 'Old Guardian',
        status: 'REVOKED',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await dbHelper.insertStudent(existingStudent);

      // Incoming backup payload
      final backupPayload = {
        'app': 'Al Ijadah Smart Pickup',
        'version': '1.0.0',
        'students': [
          {
            'id': 'AIS-2026-NEW',
            'name': 'New Restored Student',
            'grade': 'Grade 1',
            'supervisor': 'Teacher New',
            'parent_email': 'new@example.com',
            'parent_mobile': '+966 55 999 9999',
            'guardian_name': 'New Guardian',
            'status': 'APPROVED',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      };

      final result = await backupService.restoreFromParsedData(backupPayload, replaceAll: true);

      expect(result.success, isTrue);
      expect(result.studentsRestored, equals(1));

      final allStudents = await dbHelper.getAllStudents();
      expect(allStudents.length, equals(1));
      expect(allStudents.first.id, equals('AIS-2026-NEW'));
    });
  });
}
