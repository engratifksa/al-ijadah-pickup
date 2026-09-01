import 'package:flutter_test/flutter_test.dart';
import 'package:al_ijadah_pickup/models/student_model.dart';
import 'package:al_ijadah_pickup/models/email_queue_item.dart';
import 'package:al_ijadah_pickup/models/qr_payload_model.dart';

void main() {
  group('Data Models & Serialization Tests', () {
    test('StudentModel converts to and from SQLite map accurately', () {
      final student = StudentModel(
        id: 'AIS-2026-9999',
        name: 'Tariq Al-Hamdan',
        grade: 'Grade 5 - Section A',
        supervisor: 'Mr. John Smith',
        parentEmail: 'tariq.parent@example.com',
        parentMobile: '+966 51 234 5678',
        guardianName: 'Hamdan Al-Hamdan (Father)',
        photoPath: '/path/to/photo.jpg',
        status: 'APPROVED',
        updatedAt: 1725000000000,
      );

      final map = student.toSqliteMap();
      expect(map['id'], 'AIS-2026-9999');
      expect(map['parent_mobile'], '+966 51 234 5678');
      expect(map['status'], 'APPROVED');

      final reconstructed = StudentModel.fromSqliteMap(map);
      expect(reconstructed.id, student.id);
      expect(reconstructed.name, student.name);
      expect(reconstructed.parentMobile, student.parentMobile);
      expect(reconstructed.isApproved, isTrue);
    });

    test('EmailQueueItem converts to and from SQLite map', () {
      final item = EmailQueueItem(
        id: 1,
        parentEmail: 'parent@example.com',
        parentMobile: '+966 50 111 2233',
        studentName: 'Zaid Al-Mansoor',
        guardianName: 'Dr. Faisal Al-Mansoor',
        pickupTimestamp: 'Monday, 31 August 2026',
        isSent: 0,
      );

      final map = item.toSqliteMap();
      expect(map['parent_mobile'], '+966 50 111 2233');
      expect(map['is_sent'], 0);

      final reconstructed = EmailQueueItem.fromSqliteMap(map);
      expect(reconstructed.sent, isFalse);
      expect(reconstructed.studentName, 'Zaid Al-Mansoor');
    });

    test('QrPayloadModel JSON encoding and decoding', () {
      final payload = QrPayloadModel(
        studentId: 'AIS-01',
        guardianName: 'Guardian A',
        parentMobile: '+966500000000',
        parentEmail: 'a@b.com',
        timestamp: 123456789,
      );

      final jsonStr = payload.toJsonString();
      final decoded = QrPayloadModel.fromJsonString(jsonStr);

      expect(decoded.studentId, 'AIS-01');
      expect(decoded.parentMobile, '+966500000000');
      expect(decoded.timestamp, 123456789);
    });
  });
}
