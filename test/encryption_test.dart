import 'package:flutter_test/flutter_test.dart';
import 'package:al_ijadah_pickup/models/qr_payload_model.dart';
import 'package:al_ijadah_pickup/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic AES QR Encryption & Time Validation Tests', () {
    late EncryptionService encryptionService;

    setUp(() async {
      encryptionService = EncryptionService();
      await encryptionService.init();
    });

    test('Encrypted token can be decrypted accurately with all fields intact', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = QrPayloadModel(
        studentId: 'AIS-2026-1082',
        guardianName: 'Atif (Father) & Mother',
        parentMobile: '+966 50 123 4567',
        parentEmail: 'atif.parent@example.com',
        timestamp: now,
      );

      final token = encryptionService.encryptPayload(payload);
      expect(token, isNotEmpty);

      final result = encryptionService.decryptAndValidate(token);
      expect(result.isValid, isTrue);
      expect(result.status, equals(QrValidationStatus.valid));
      expect(result.payload?.studentId, equals('AIS-2026-1082'));
      expect(result.payload?.guardianName, equals('Atif (Father) & Mother'));
      expect(result.payload?.parentMobile, equals('+966 50 123 4567'));
      expect(result.payload?.parentEmail, equals('atif.parent@example.com'));
    });

    test('Old static screenshot token (>45s old) is correctly flagged as EXPIRED', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 60 seconds in the past (exceeds 45s validity window)
      final staleTimestamp = now - 60000;

      final payload = QrPayloadModel(
        studentId: 'AIS-2026-1082',
        guardianName: 'Dr. Faisal Al-Mansoor',
        parentMobile: '+966 50 123 4567',
        parentEmail: 'parent.zaid@example.com',
        timestamp: staleTimestamp,
      );

      final token = encryptionService.encryptPayload(payload);
      final result = encryptionService.decryptAndValidate(token, simulatedNowEpochMs: now);

      expect(result.isValid, isFalse);
      expect(result.status, equals(QrValidationStatus.expired));
      expect(result.ageSeconds, greaterThanOrEqualTo(55));
    });

    test('Token with future timestamp (>20s in future) is flagged as TAMPERED', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 35 seconds into the future (exceeds 20s tolerance)
      final futureTimestamp = now + 35000;

      final payload = QrPayloadModel(
        studentId: 'AIS-2026-1082',
        guardianName: 'Dr. Faisal Al-Mansoor',
        parentMobile: '+966 50 123 4567',
        parentEmail: 'parent.zaid@example.com',
        timestamp: futureTimestamp,
      );

      final token = encryptionService.encryptPayload(payload);
      final result = encryptionService.decryptAndValidate(token, simulatedNowEpochMs: now);

      expect(result.isValid, isFalse);
      expect(result.status, equals(QrValidationStatus.tampered));
    });

    test('Replayed or duplicate screenshot token is flagged as TAMPERED', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = QrPayloadModel(
        studentId: 'AIS-2026-9999',
        guardianName: 'Dr. Faisal Al-Mansoor',
        parentMobile: '+966 50 123 4567',
        parentEmail: 'parent.zaid@example.com',
        timestamp: now,
      );

      final token = encryptionService.encryptPayload(payload);
      final result1 = encryptionService.decryptAndValidate(token, simulatedNowEpochMs: now);
      expect(result1.isValid, isTrue);

      encryptionService.markTokenConsumed(payload);

      final result2 = encryptionService.decryptAndValidate(token, simulatedNowEpochMs: now);
      expect(result2.isValid, isFalse);
      expect(result2.status, equals(QrValidationStatus.tampered));
      expect(result2.message, contains('Screenshot'));
    });

    test('Corrupted or invalid token string is handled gracefully without crashing', () {
      const corruptToken = 'INVALID_CIPHERTEXT_12345';
      final result = encryptionService.decryptAndValidate(corruptToken);

      expect(result.isValid, isFalse);
      expect(result.status, equals(QrValidationStatus.invalidKeyOrFormat));
      expect(result.payload, isNull);
    });
  });
}
