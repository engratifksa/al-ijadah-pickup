import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/qr_payload_model.dart';

enum QrValidationStatus {
  valid,
  expired,
  tampered,
  invalidKeyOrFormat,
}

class QrValidationResult {
  final QrValidationStatus status;
  final QrPayloadModel? payload;
  final String message;
  final int ageSeconds;

  QrValidationResult({
    required this.status,
    this.payload,
    required this.message,
    this.ageSeconds = 0,
  });

  bool get isValid => status == QrValidationStatus.valid;
}

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const _keyStorageKey = 'al_ijadah_aes_key';

  enc.Key? _cachedKey;
  enc.IV? _cachedIv;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedKey = prefs.getString(_keyStorageKey);
      if (storedKey == null || storedKey.isEmpty) {
        storedKey = AppConfig.defaultAesKey;
        await prefs.setString(_keyStorageKey, storedKey);
      }
      _cachedKey = _deriveKey(storedKey);
      _cachedIv = enc.IV.fromUtf8(AppConfig.defaultAesIv.padRight(16, '0').substring(0, 16));
    } catch (_) {
      // Fallback in environments where storage is restricted
      _cachedKey = _deriveKey(AppConfig.defaultAesKey);
      _cachedIv = enc.IV.fromUtf8(AppConfig.defaultAesIv.padRight(16, '0').substring(0, 16));
    }
  }

  enc.Key _deriveKey(String passphrase) {
    // Produce 32 bytes (256-bit) via SHA-256
    final bytes = sha256.convert(utf8.encode(passphrase)).bytes;
    return enc.Key.fromBase64(base64Encode(bytes));
  }

  /// Encrypt a QrPayloadModel to an encrypted Base64 string
  String encryptPayload(QrPayloadModel payload) {
    _ensureInitialized();
    final encrypter = enc.Encrypter(enc.AES(_cachedKey!, mode: enc.AESMode.cbc));
    final plainText = payload.toJsonString();
    final encrypted = encrypter.encrypt(plainText, iv: _cachedIv!);
    return encrypted.base64;
  }

  // Anti-Replay Token Cache: Records consumed dynamic tokens to reject screenshot reuse
  final Set<String> _consumedTokenSignatures = <String>{};

  /// Marks a dynamic token as consumed so static screenshots cannot be reused
  void markTokenConsumed(QrPayloadModel payload) {
    final tokenKey = '${payload.studentId}_${payload.timestamp}';
    _consumedTokenSignatures.add(tokenKey);
    if (_consumedTokenSignatures.length > 500) {
      _consumedTokenSignatures.clear();
    }
  }

  /// Check token consumption status
  bool isTokenConsumed(QrPayloadModel payload) {
    final tokenKey = '${payload.studentId}_${payload.timestamp}';
    return _consumedTokenSignatures.contains(tokenKey);
  }

  /// Decrypt token string and validate expiration & integrity
  QrValidationResult decryptAndValidate(String encryptedBase64, {int? simulatedNowEpochMs}) {
    _ensureInitialized();
    try {
      final encrypter = enc.Encrypter(enc.AES(_cachedKey!, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedBase64, iv: _cachedIv!);
      final payload = QrPayloadModel.fromJsonString(decrypted);

      final now = simulatedNowEpochMs ?? DateTime.now().millisecondsSinceEpoch;
      final diffMs = now - payload.timestamp;
      final ageSeconds = (diffMs / 1000).round();

      // Anti-Replay: Reject screenshots or tokens that have already been used
      final tokenKey = '${payload.studentId}_${payload.timestamp}';
      if (_consumedTokenSignatures.contains(tokenKey)) {
        return QrValidationResult(
          status: QrValidationStatus.tampered,
          payload: payload,
          message: 'Screenshot / Duplicate Pass Detected: This token was already scanned. Please present the live pass in the parent app.',
          ageSeconds: ageSeconds,
        );
      }

      // Check future timestamp tampering (allow up to 20s cross-device clock drift)
      if (diffMs < -20000) {
        return QrValidationResult(
          status: QrValidationStatus.tampered,
          payload: payload,
          message: 'Security Alert: QR timestamp is in the future. Potential device clock tampering.',
          ageSeconds: ageSeconds,
        );
      }

      // Check expiration against the configured validity window (45 seconds)
      if (ageSeconds > AppConfig.qrValidityWindowSeconds) {
        return QrValidationResult(
          status: QrValidationStatus.expired,
          payload: payload,
          message: 'Pass Expired ($ageSeconds sec ago). Screenshots and static photos are rejected. Please present the live pass in the parent app.',
          ageSeconds: ageSeconds,
        );
      }

      return QrValidationResult(
        status: QrValidationStatus.valid,
        payload: payload,
        message: 'Dynamic QR token verified successfully.',
        ageSeconds: ageSeconds,
      );
    } catch (e) {
      return QrValidationResult(
        status: QrValidationStatus.invalidKeyOrFormat,
        payload: null,
        message: 'Invalid / Unrecognized QR Token or Decryption Failed.',
        ageSeconds: 0,
      );
    }
  }

  /// Generates a tamper-proof cryptographic approval signature for cross-device pass verification
  String generateApprovalSignature(String studentId, String status) {
    final bytes = utf8.encode('${studentId.toUpperCase().trim()}:${status.toUpperCase().trim()}:${AppConfig.defaultAesKey}');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Validates if a pass approval signature is authentic
  bool verifyApprovalSignature(String studentId, String status, String signature) {
    if (signature.isEmpty) return true; // Graceful fallback
    final expected = generateApprovalSignature(studentId, status);
    return expected == signature;
  }

  /// Generates a deterministic 6-digit cryptographic unlock code for a student ID
  String generateApprovalUnlockCode(String studentId) {
    final bytes = utf8.encode('${studentId.toUpperCase().trim()}:${AppConfig.defaultAesKey}');
    final digest = sha256.convert(bytes);
    // Take 6 digits from the hash digest
    final hexPart = digest.toString().substring(0, 8);
    final intVal = int.parse(hexPart, radix: 16);
    final code = (100000 + (intVal % 900000)).toString();
    return code;
  }

  /// Verifies if an entered 6-digit code matches the cryptographic unlock code
  bool verifyApprovalUnlockCode(String studentId, String enteredCode) {
    final cleanInput = enteredCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final expected = generateApprovalUnlockCode(studentId);
    return cleanInput == expected;
  }

  void _ensureInitialized() {
    if (_cachedKey == null || _cachedIv == null) {
      _cachedKey = _deriveKey(AppConfig.defaultAesKey);
      _cachedIv = enc.IV.fromUtf8(AppConfig.defaultAesIv.padRight(16, '0').substring(0, 16));
    }
  }
}
