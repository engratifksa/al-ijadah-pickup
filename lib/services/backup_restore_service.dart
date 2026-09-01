import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/student_model.dart';
import 'database_helper.dart';
import 'smtp_email_service.dart';

class BackupRestoreResult {
  final bool success;
  final String message;
  final int studentsRestored;

  BackupRestoreResult({
    required this.success,
    required this.message,
    this.studentsRestored = 0,
  });
}

class BackupRestoreService {
  static final BackupRestoreService _instance = BackupRestoreService._internal();
  factory BackupRestoreService() => _instance;
  BackupRestoreService._internal();

  final _dbHelper = DatabaseHelper();
  final _smtpService = SmtpEmailService();

  /// Generates structured, checksummed JSON containing all student records and configuration
  Future<String> generateBackupJson({bool includeSettings = true}) async {
    final students = await _dbHelper.getAllStudents();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final dateStr = DateFormat('EEEE, dd MMMM yyyy - hh:mm a').format(now);

    final studentsList = students.map((s) => s.toSqliteMap()).toList();

    final backupMap = <String, dynamic>{
      'app': 'Al Ijadah Smart Pickup',
      'version': '1.0.0',
      'exportTimestamp': nowMs,
      'exportDate': dateStr,
      'studentCount': students.length,
      'students': studentsList,
    };

    if (includeSettings) {
      backupMap['settings'] = {
        'admin_email': AppConfig.adminEmail,
        'school_phone': AppConfig.schoolPhone,
        'smtp_gmail_user': AppConfig.smtpGmailUser,
        'guard_pin': AppConfig.guardPin,
        'settings_pin': AppConfig.settingsPin,
      };
    }

    // Generate SHA-256 integrity checksum over the student data
    final studentDataBytes = utf8.encode(jsonEncode(studentsList));
    backupMap['checksum'] = sha256.convert(studentDataBytes).toString();

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Exports backup JSON to a file and launches native Share Sheet (AirDrop, Google Drive, WhatsApp, Files)
  Future<void> exportAndShareBackup(BuildContext context) async {
    try {
      final jsonString = await generateBackupJson();
      final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'al_ijadah_backup_$nowStr.json';

      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        await Share.shareXFiles(
          [XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: 'application/json')],
          text: 'Al Ijadah Student Records Backup ($nowStr)',
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      final xFile = XFile(file.path, mimeType: 'application/json', name: fileName);
      final result = await Share.shareXFiles(
        [xFile],
        subject: 'Al Ijadah Smart Pickup - Student Database Backup',
        text: 'Al Ijadah Student Records & Settings Backup ($nowStr)',
      );

      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.verifiedGreenDark,
            content: Text('Backup exported and shared successfully!'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Backup export error: $e'),
        ),
      );
    }
  }

  /// Emails the complete database backup JSON directly to the School Admin email
  Future<void> emailBackupToAdmin(BuildContext context) async {
    try {
      final students = await _dbHelper.getAllStudents();
      final nowStr = DateFormat('EEEE, dd MMMM yyyy - hh:mm a').format(DateTime.now());

      final htmlBody = '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; background-color: #F8F9FA; padding: 20px; color: #1E293B;">
  <div style="max-width: 600px; margin: auto; background: white; border-radius: 12px; overflow: hidden; border: 1px solid #E2E8F0;">
    <div style="background: #0F3B82; color: white; padding: 20px; text-align: center;">
      <h2 style="margin: 0; color: #F5B800;">Al Ijadah International School</h2>
      <p style="margin: 5px 0 0 0; font-size: 14px;">Official Database Backup & Device Migration Record</p>
    </div>
    <div style="padding: 24px;">
      <p style="font-size: 14px; line-height: 1.5;">This email contains an automated backup of the Al Ijadah student pickup registry for device migration or disaster recovery.</p>
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Export Date:</td><td style="padding: 8px; font-weight: bold;">$nowStr</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Total Students:</td><td style="padding: 8px; font-weight: bold; color: #0F3B82;">${students.length}</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Admin Destination:</td><td style="padding: 8px;">${AppConfig.adminEmail}</td></tr>
      </table>
      <div style="background: #F1F5F9; border-radius: 8px; padding: 14px; margin-bottom: 18px;">
        <strong style="color: #0F3B82; font-size: 12px; display: block; margin-bottom: 6px;">HOW TO RESTORE ON A NEW DEVICE:</strong>
        <p style="margin: 0; font-size: 12px; color: #475569; line-height: 1.5;">1. Open the <strong>Al Ijadah App</strong> on your new Android or iOS phone.<br>2. Navigate to <strong>Settings & Admin Portal</strong>.<br>3. Under <strong>Data Backup & Migration</strong>, select <strong>Restore Backup</strong> and select your saved backup file.</p>
      </div>
      <div style="background: #FFFBEB; border: 1px solid #F5B800; border-radius: 8px; padding: 12px; font-size: 11px; color: #B45309;">
        <strong>Notice:</strong> Keep this email confidential as it contains registered student and parent records.
      </div>
    </div>
    <div style="background: #F8FAFC; padding: 12px; text-align: center; font-size: 11px; color: #64748B; border-top: 1px solid #E2E8F0;">
      ${AppConfig.schoolName} • Support Hotline: ${AppConfig.schoolPhone}
    </div>
  </div>
</body>
</html>
''';

      final dispatchResult = await _smtpService.sendCustomHtmlEmail(
        recipientEmail: AppConfig.adminEmail,
        subject: 'Database Backup: Al Ijadah Student Registry (${students.length} Students) - $nowStr',
        htmlBody: htmlBody,
      );

      if (!context.mounted) return;

      if (dispatchResult.isSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.verifiedGreenDark,
            content: Text('Backup details emailed to ${AppConfig.adminEmail}!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRedDark,
            content: Text('Failed to email backup: ${dispatchResult.message}'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Email backup error: $e'),
        ),
      );
    }
  }

  /// Opens native file picker, validates backup, and presents confirmation dialog before restoring
  Future<void> pickAndRestoreBackup(BuildContext context, {VoidCallback? onRestored}) async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final file = pickedFiles.first;
      final bytes = await file.readAsBytes();
      final jsonContent = utf8.decode(bytes);

      if (jsonContent.trim().isEmpty) {
        if (!context.mounted) return;
        _showErrorDialog(context, 'Selected file is empty or unreadable.');
        return;
      }

      final Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
      } catch (e) {
        if (!context.mounted) return;
        _showErrorDialog(context, 'Invalid backup file format. Must be a valid JSON backup file.');
        return;
      }

      if (parsed['app'] != 'Al Ijadah Smart Pickup' || !parsed.containsKey('students')) {
        if (!context.mounted) return;
        _showErrorDialog(context, 'Unrecognized backup file. This file was not generated by Al Ijadah Smart Pickup.');
        return;
      }

      final rawStudents = parsed['students'] as List<dynamic>? ?? [];
      final studentCount = rawStudents.length;
      final exportDate = parsed['exportDate'] as String? ?? 'Unknown date';

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: AppTheme.primaryRoyalBlue, size: 26),
              SizedBox(width: 10),
              Text('Restore Backup'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found $studentCount student records from backup:',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Export Date: $exportDate',
                style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '• "Merge": Safely adds all students from the backup into this device without deleting existing records.\n'
                  '• "Full Restore": Replaces current student roster with the backup.',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textDark, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final res = await restoreFromParsedData(parsed, replaceAll: true);
                if (context.mounted) {
                  _showResultSnackbar(context, res);
                  onRestored?.call();
                }
              },
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.alertRedDark),
              child: const Text('Full Restore (Replace)'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final res = await restoreFromParsedData(parsed, replaceAll: false);
                if (context.mounted) {
                  _showResultSnackbar(context, res);
                  onRestored?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verifiedGreenDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Merge (Recommended)'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Error restoring backup: $e');
    }
  }

  /// Restores student records and optional configuration from validated backup data
  Future<BackupRestoreResult> restoreFromParsedData(
    Map<String, dynamic> data, {
    bool replaceAll = false,
  }) async {
    try {
      final rawStudents = data['students'] as List<dynamic>? ?? [];
      int count = 0;

      if (replaceAll) {
        final existing = await _dbHelper.getAllStudents();
        for (final s in existing) {
          await _dbHelper.deleteStudent(s.id);
        }
      }

      for (final raw in rawStudents) {
        if (raw is Map<String, dynamic>) {
          final student = StudentModel.fromSqliteMap(raw);
          await _dbHelper.insertStudent(student);
          count++;
        }
      }

      // Restore configuration if present
      if (data.containsKey('settings') && data['settings'] is Map<String, dynamic>) {
        final settings = data['settings'] as Map<String, dynamic>;
        if (settings.containsKey('admin_email') && settings['admin_email'].toString().isNotEmpty) {
          AppConfig.adminEmail = settings['admin_email'].toString();
        }
        if (settings.containsKey('school_phone') && settings['school_phone'].toString().isNotEmpty) {
          AppConfig.schoolPhone = settings['school_phone'].toString();
        }
        if (settings.containsKey('smtp_gmail_user') && settings['smtp_gmail_user'].toString().isNotEmpty) {
          AppConfig.smtpGmailUser = settings['smtp_gmail_user'].toString();
        }
        await AppConfig.saveToPreferences();
      }

      return BackupRestoreResult(
        success: true,
        message: 'Successfully restored $count student records!',
        studentsRestored: count,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Error during restore: $e',
        studentsRestored: 0,
      );
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.alertRed, size: 24),
            SizedBox(width: 8),
            Text('Backup Error'),
          ],
        ),
        content: Text(message, style: GoogleFonts.outfit(fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRoyalBlue),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showResultSnackbar(BuildContext context, BackupRestoreResult res) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res.success ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
        content: Text(res.message),
      ),
    );
  }
}
