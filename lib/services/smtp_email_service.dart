import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/app_config.dart';
import '../models/email_queue_item.dart';
import 'database_helper.dart';

enum EmailDispatchStatus {
  sentDirectly,
  queuedOffline,
  failed,
}

class EmailDispatchResult {
  final EmailDispatchStatus status;
  final String message;
  final int? queueId;

  EmailDispatchResult({
    required this.status,
    required this.message,
    this.queueId,
  });

  bool get isSuccessful =>
      status == EmailDispatchStatus.sentDirectly || status == EmailDispatchStatus.queuedOffline;
}

class SmtpEmailService {
  static final SmtpEmailService _instance = SmtpEmailService._internal();
  factory SmtpEmailService() => _instance;
  SmtpEmailService._internal();

  final _dbHelper = DatabaseHelper();
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isFlushing = false;

  final ValueNotifier<int> pendingQueueCount = ValueNotifier<int>(0);
  final ValueNotifier<String> lastDispatchLog = ValueNotifier<String>('Ready');

  Future<void> init() async {
    await updatePendingCount();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('[SmtpEmailService] Network restored. Flushing offline email queue...');
        flushPendingQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> updatePendingCount() async {
    try {
      final count = await _dbHelper.getPendingQueueCount();
      pendingQueueCount.value = count;
    } catch (_) {}
  }

  /// Sends a pickup confirmation email or queues it in SQLite if offline or send fails
  Future<EmailDispatchResult> sendPickupConfirmation({
    required String parentEmail,
    required String parentMobile,
    required String studentName,
    required String guardianName,
    DateTime? pickupTime,
  }) async {
    final timeStr = DateFormat('EEEE, dd MMMM yyyy - hh:mm:ss a')
        .format(pickupTime ?? DateTime.now());

    // 1. Check network connectivity
    bool isOnline = true;
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      isOnline = true; // Fallback to attempting direct send
    }

    if (!isOnline) {
      // Save directly to SQLite queue
      final queueId = await _dbHelper.queueEmail(EmailQueueItem(
        parentEmail: parentEmail,
        parentMobile: parentMobile,
        studentName: studentName,
        guardianName: guardianName,
        pickupTimestamp: timeStr,
        isSent: 0,
      ));
      await updatePendingCount();
      lastDispatchLog.value = 'Saved to offline queue (Queue #$queueId)';
      return EmailDispatchResult(
        status: EmailDispatchStatus.queuedOffline,
        message: 'Device is offline. Pickup confirmation saved to local queue and will send automatically when connected.',
        queueId: queueId,
      );
    }

    // 2. Attempt direct SMTP transmission
    try {
      await _executeSmtpSend(
        recipientEmail: parentEmail,
        parentMobile: parentMobile,
        studentName: studentName,
        guardianName: guardianName,
        timestampStr: timeStr,
      );

      // Successfully sent directly; also record as sent item in DB history
      await _dbHelper.queueEmail(EmailQueueItem(
        parentEmail: parentEmail,
        parentMobile: parentMobile,
        studentName: studentName,
        guardianName: guardianName,
        pickupTimestamp: timeStr,
        isSent: 1,
      ));
      await updatePendingCount();
      lastDispatchLog.value = 'Instant SMTP notification delivered to $parentEmail';

      return EmailDispatchResult(
        status: EmailDispatchStatus.sentDirectly,
        message: 'Direct SMTP confirmation email sent successfully to $parentEmail.',
      );
    } catch (e) {
      debugPrint('[SmtpEmailService] Direct SMTP failed ($e). Enqueueing to offline SQLite queue...');
      final queueId = await _dbHelper.queueEmail(EmailQueueItem(
        parentEmail: parentEmail,
        parentMobile: parentMobile,
        studentName: studentName,
        guardianName: guardianName,
        pickupTimestamp: timeStr,
        isSent: 0,
        errorMessage: e.toString(),
      ));
      await updatePendingCount();
      lastDispatchLog.value = 'Queued for retry (SMTP error: $e)';

      return EmailDispatchResult(
        status: EmailDispatchStatus.queuedOffline,
        message: 'SMTP dispatch temporarily failed. Queued in local database for automatic retry.',
        queueId: queueId,
      );
    }
  }

  /// Web HTTP Dispatcher (Method 1)
  /// Dispatches email over HTTPS REST without requiring raw TCP sockets.
  Future<bool> _dispatchWebHttpEmail({
    required String recipient,
    required String subject,
    required String htmlContent,
  }) async {
    final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
        AppConfig.cleanSmtpPassword.length == 16 &&
        AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

    // 1. Try remote HTTPS email gateway if configured
    if (AppConfig.webHttpGatewayUrl.isNotEmpty) {
      try {
        final resp = await http.post(
          Uri.parse(AppConfig.webHttpGatewayUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'recipient': recipient,
            'subject': subject,
            'html': htmlContent,
            'user': AppConfig.smtpGmailUser,
            'pass': AppConfig.cleanSmtpPassword,
            'senderName': AppConfig.smtpSenderName,
          }),
        ).timeout(const Duration(seconds: 10));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          debugPrint('[SmtpEmailService] Web HTTP gateway delivered to $recipient');
          return true;
        }
      } catch (e) {
        debugPrint('[SmtpEmailService] Web HTTP gateway error: $e');
      }
    }

    // 2. Try local development bridge (http://127.0.0.1:8085) for PC testing
    try {
      final resp = await http.post(
        Uri.parse('http://127.0.0.1:${AppConfig.webBridgePort}/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user': AppConfig.smtpGmailUser,
          'pass': AppConfig.cleanSmtpPassword,
          'recipient': recipient,
          'subject': subject,
          'html': htmlContent,
          'senderName': AppConfig.smtpSenderName,
        }),
      ).timeout(const Duration(seconds: 4));

      final result = jsonDecode(resp.body) as Map<String, dynamic>;
      if (result['success'] == true) {
        debugPrint('[SmtpEmailService] Web local bridge delivered to $recipient');
        return true;
      }
    } catch (e) {
      debugPrint('[SmtpEmailService] Web local bridge note: $e');
    }

    // 3. Fallback: if mock enabled or offline simulation
    if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
      debugPrint('[SmtpEmailService] Web simulated email for $recipient.');
      return true;
    }

    return false;
  }

  /// Internal direct SMTP dispatch using mailer package or web bridge
  Future<void> _executeSmtpSend({
    required String recipientEmail,
    required String parentMobile,
    required String studentName,
    required String guardianName,
    required String timestampStr,
  }) async {
    final htmlContent = _generateBrandedEmailHtml(
      studentName: studentName,
      guardianName: guardianName,
      parentMobile: parentMobile,
      timestampStr: timestampStr,
    );

    final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
        AppConfig.cleanSmtpPassword.length == 16 &&
        AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

    if (kIsWeb) {
      final success = await _dispatchWebHttpEmail(
        recipient: recipientEmail,
        subject: 'Safety Alert: Pickup Confirmation - Al Ijadah International School',
        htmlContent: htmlContent,
      );
      if (success) return;
      if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) return;
      throw Exception('Web email gateway unreachable. Please ensure internet connection.');
    }

    if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('[SmtpEmailService] Mock direct SMTP dispatch executed for $recipientEmail ($studentName).');
      return;
    }

    final smtpServer = SmtpServer(
      AppConfig.smtpHost,
      port: AppConfig.smtpPortSsl,
      ssl: true,
      username: AppConfig.smtpGmailUser,
      password: AppConfig.cleanSmtpPassword,
    );

    final message = Message()
      ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
      ..recipients.add(recipientEmail)
      ..subject = 'Safety Alert: Pickup Confirmation - Al Ijadah International School'
      ..html = htmlContent;

    await send(message, smtpServer);
  }

  /// Explicitly tests SMTP connection with user-configured credentials
  Future<EmailDispatchResult> testSmtpConnection({required String recipientEmail}) async {
    final timeStr = DateFormat('EEEE, dd MMMM yyyy - hh:mm:ss a').format(DateTime.now());

    final htmlContent = '''
    <div style="font-family: Arial, sans-serif; padding: 24px; background-color: #f8fafc; color: #1e293b;">
      <div style="background: linear-gradient(135deg, #072454, #0F3B82); padding: 24px; border-radius: 12px; color: white; text-align: center;">
        <h2 style="margin: 0; color: #FFFFFF;">Al Ijadah International School</h2>
        <p style="margin: 6px 0 0 0; color: #F5B800; font-weight: bold; font-size: 14px;">Direct SMTP Connection Verified</p>
      </div>
      <div style="background-color: white; padding: 20px; border-radius: 12px; margin-top: 18px; border: 1px solid #e2e8f0;">
        <p style="font-size: 15px; font-weight: bold; color: #0F3B82;">Direct Gmail Dispatch Test Successful!</p>
        <p style="font-size: 13px; color: #475569;">Your school Gmail credentials and App Password have been validated against <code>${AppConfig.smtpHost}:${AppConfig.smtpPortSsl}</code>.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 16px 0;" />
        <p style="font-size: 12px; color: #64748b; margin: 4px 0;"><strong>Sender Account:</strong> ${AppConfig.smtpGmailUser}</p>
        <p style="font-size: 12px; color: #64748b; margin: 4px 0;"><strong>Admin Email:</strong> ${AppConfig.adminEmail}</p>
        <p style="font-size: 12px; color: #64748b; margin: 4px 0;"><strong>Timestamp:</strong> $timeStr</p>
      </div>
    </div>
    ''';

    if (kIsWeb) {
      try {
        final resp = await http.post(
          Uri.parse('http://127.0.0.1:${AppConfig.webBridgePort}/send-email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user': AppConfig.smtpGmailUser,
            'pass': AppConfig.cleanSmtpPassword,
            'recipient': recipientEmail,
            'subject': 'Al Ijadah Pickup Pass - Live SMTP Verification',
            'html': htmlContent,
            'senderName': AppConfig.smtpSenderName,
          }),
        ).timeout(const Duration(seconds: 15));

        final result = jsonDecode(resp.body) as Map<String, dynamic>;
        if (result['success'] == true) {
          return EmailDispatchResult(
            status: EmailDispatchStatus.sentDirectly,
            message: 'Success! Live test email dispatched from ${AppConfig.smtpGmailUser} to $recipientEmail! Check your inbox.',
          );
        } else {
          return EmailDispatchResult(
            status: EmailDispatchStatus.failed,
            message: 'Google SMTP Error: ${result['error']}\n\nPlease check:\n1. 2-Step Verification is active on Google.\n2. You used a 16-character Google App Password (not normal login password).\n3. Sender address is correct.',
          );
        }
      } catch (e) {
        return EmailDispatchResult(
          status: EmailDispatchStatus.failed,
          message: 'Error communicating with local SMTP service: $e\n\nEnsure local SMTP bridge is running, or test natively on Windows/Android.',
        );
      }
    }

    try {
      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPortSsl,
        ssl: true,
        username: AppConfig.smtpGmailUser,
        password: AppConfig.cleanSmtpPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Al Ijadah Pickup Pass - Test Email Dispatch'
        ..html = htmlContent;

      await send(message, smtpServer);

      return EmailDispatchResult(
        status: EmailDispatchStatus.sentDirectly,
        message: 'Success! Test email sent from ${AppConfig.smtpGmailUser} to $recipientEmail.',
      );
    } catch (e) {
      debugPrint('[SmtpEmailService] Test dispatch failed: $e');
      return EmailDispatchResult(
        status: EmailDispatchStatus.failed,
        message: 'SMTP Test Failed: $e\n\nTip: For Gmail, ensure 2-Step Verification is active and use a 16-character App Password (not your normal Gmail login password).',
      );
    }
  }

  /// Flushes all pending unsent emails from SQLite table `email_queue`
  Future<int> flushPendingQueue() async {
    if (_isFlushing) return 0;
    _isFlushing = true;

    int successCount = 0;
    try {
      final pendingItems = await _dbHelper.getPendingEmails();
      if (pendingItems.isEmpty) {
        _isFlushing = false;
        return 0;
      }

      debugPrint('[SmtpEmailService] Flushing ${pendingItems.length} queued emails...');
      for (final item in pendingItems) {
        try {
          await _executeSmtpSend(
            recipientEmail: item.parentEmail,
            parentMobile: item.parentMobile,
            studentName: item.studentName,
            guardianName: item.guardianName,
            timestampStr: item.pickupTimestamp,
          );

          if (item.id != null) {
            await _dbHelper.markEmailSent(item.id!);
            successCount++;
          }
        } catch (e) {
          debugPrint('[SmtpEmailService] Failed to flush queue item #${item.id}: $e');
          // Leave in queue for next cycle
        }
      }

      await updatePendingCount();
      lastDispatchLog.value = 'Flushed $successCount/${pendingItems.length} queued emails.';
    } finally {
      _isFlushing = false;
    }
    return successCount;
  }

  /// Sends an email to the School Admin with student registration details and unlock code
  Future<bool> sendAdminRegistrationNotification({
    required String studentId,
    required String studentName,
    required String grade,
    required String supervisor,
    required String guardianName,
    required String parentMobile,
    required String parentEmail,
    required String approvalCode,
  }) async {
    try {
      final htmlContent = _generateAdminRegistrationEmailHtml(
        studentId: studentId,
        studentName: studentName,
        grade: grade,
        supervisor: supervisor,
        guardianName: guardianName,
        parentMobile: parentMobile,
        parentEmail: parentEmail,
        approvalCode: approvalCode,
      );

      final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
          AppConfig.cleanSmtpPassword.length == 16 &&
          AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

      if (kIsWeb) {
        final success = await _dispatchWebHttpEmail(
          recipient: AppConfig.adminEmail,
          subject: 'New Student Pass Registration: $studentName ($grade) - Action Required',
          htmlContent: htmlContent,
        );
        if (success) {
          debugPrint('[SmtpEmailService] Admin registration alert sent via Web HTTP gateway to ${AppConfig.adminEmail}');
          return true;
        }
        if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
          debugPrint('[SmtpEmailService] Mock Admin registration alert sent for $studentName.');
          return true;
        }
      }

      if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
        debugPrint('[SmtpEmailService] Mock Admin registration alert sent for $studentName (Code: $approvalCode).');
        return true;
      }

      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPortSsl,
        ssl: true,
        username: AppConfig.smtpGmailUser,
        password: AppConfig.cleanSmtpPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
        ..recipients.add(AppConfig.adminEmail)
        ..subject = 'New Student Pass Registration: $studentName ($grade) - Action Required'
        ..html = htmlContent;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[SmtpEmailService] Failed to email admin: $e');
      return false;
    }
  }

  /// Sends the official Approval Code to the Parent's email address
  Future<bool> sendParentApprovalCodeEmail({
    required String parentEmail,
    required String studentName,
    required String studentId,
    required String approvalCode,
  }) async {
    try {
      final htmlContent = _generateParentApprovalEmailHtml(
        studentName: studentName,
        studentId: studentId,
        approvalCode: approvalCode,
      );

      final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
          AppConfig.cleanSmtpPassword.length == 16 &&
          AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

      if (kIsWeb) {
        final success = await _dispatchWebHttpEmail(
          recipient: parentEmail,
          subject: 'Approved: Al Ijadah Pickup Pass Unlock Code for $studentName',
          htmlContent: htmlContent,
        );
        if (success) {
          debugPrint('[SmtpEmailService] Parent approval email sent via Web HTTP gateway to $parentEmail');
          return true;
        }
        if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
          debugPrint('[SmtpEmailService] Mock approval code email dispatched to $parentEmail.');
          return true;
        }
      }

      if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
        debugPrint('[SmtpEmailService] Mock approval code email dispatched to $parentEmail (Code: $approvalCode).');
        return true;
      }

      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPortSsl,
        ssl: true,
        username: AppConfig.smtpGmailUser,
        password: AppConfig.cleanSmtpPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
        ..recipients.add(parentEmail)
        ..subject = 'Approved: Al Ijadah Pickup Pass Unlock Code for $studentName'
        ..html = htmlContent;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[SmtpEmailService] Failed to email parent approval code: $e');
      return false;
    }
  }

  /// Sends the Admin / Settings Passcode to the school administrator's registered email
  Future<bool> sendAdminPasscodeRecoveryEmail({
    required String adminEmail,
    required String passcode,
  }) async {
    try {
      final timeStr = DateFormat('EEEE, dd MMMM yyyy - hh:mm:ss a').format(DateTime.now());
      final htmlContent = _generatePasscodeRecoveryEmailHtml(
        adminEmail: adminEmail,
        passcode: passcode,
        timestampStr: timeStr,
      );

      final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
          AppConfig.cleanSmtpPassword.length == 16 &&
          AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

      if (kIsWeb) {
        try {
          final resp = await http.post(
            Uri.parse('http://127.0.0.1:${AppConfig.webBridgePort}/send-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user': AppConfig.smtpGmailUser,
              'pass': AppConfig.cleanSmtpPassword,
              'recipient': adminEmail,
              'subject': 'Security Recovery: Admin Settings Passcode - Al Ijadah School',
              'html': htmlContent,
              'senderName': AppConfig.smtpSenderName,
            }),
          ).timeout(const Duration(seconds: 12));

          final result = jsonDecode(resp.body) as Map<String, dynamic>;
          if (result['success'] == true) {
            debugPrint('[SmtpEmailService] Passcode recovery email sent via web bridge to $adminEmail');
            return true;
          }
        } catch (e) {
          debugPrint('[SmtpEmailService] Web bridge recovery send error: $e');
        }

        if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
          debugPrint('[SmtpEmailService] Mock Passcode recovery email dispatched to $adminEmail (Passcode: $passcode).');
          return true;
        }
      }

      if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
        debugPrint('[SmtpEmailService] Mock Passcode recovery email dispatched to $adminEmail (Passcode: $passcode).');
        return true;
      }

      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPortSsl,
        ssl: true,
        username: AppConfig.smtpGmailUser,
        password: AppConfig.cleanSmtpPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
        ..recipients.add(adminEmail)
        ..subject = 'Security Recovery: Admin Settings Passcode - Al Ijadah School'
        ..html = htmlContent;

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[SmtpEmailService] Failed to send passcode recovery email: $e');
      return false;
    }
  }

  /// Sends a custom HTML email (e.g. database backup dispatches, admin notices)
  Future<EmailDispatchResult> sendCustomHtmlEmail({
    required String recipientEmail,
    required String subject,
    required String htmlBody,
  }) async {
    try {
      final isConfigured = AppConfig.smtpGmailUser.contains('@') &&
          AppConfig.cleanSmtpPassword.length == 16 &&
          AppConfig.cleanSmtpPassword != 'abcdefghijklmnop';

      if (kIsWeb) {
        final success = await _dispatchWebHttpEmail(
          recipient: recipientEmail,
          subject: subject,
          htmlContent: htmlBody,
        );
        if (success) {
          return EmailDispatchResult(
            status: EmailDispatchStatus.sentDirectly,
            message: 'Email dispatched successfully via Web HTTP gateway.',
          );
        }
        if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
          return EmailDispatchResult(
            status: EmailDispatchStatus.sentDirectly,
            message: 'Email simulated successfully (Mock Mode).',
          );
        }
      }

      if (!isConfigured && AppConfig.enableMockSmtpWhenOfflineOrEmpty) {
        return EmailDispatchResult(
          status: EmailDispatchStatus.sentDirectly,
          message: 'Email simulated successfully (Mock Mode).',
        );
      }

      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPortSsl,
        ssl: true,
        username: AppConfig.smtpGmailUser,
        password: AppConfig.cleanSmtpPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.smtpGmailUser, AppConfig.smtpSenderName)
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlBody;

      await send(message, smtpServer);
      return EmailDispatchResult(
        status: EmailDispatchStatus.sentDirectly,
        message: 'Email dispatched directly to $recipientEmail.',
      );
    } catch (e) {
      debugPrint('[SmtpEmailService] Failed to send custom HTML email: $e');
      return EmailDispatchResult(
        status: EmailDispatchStatus.failed,
        message: 'Email dispatch error: $e',
      );
    }
  }

  /// HTML for Admin Passcode Recovery Email
  String _generatePasscodeRecoveryEmailHtml({
    required String adminEmail,
    required String passcode,
    required String timestampStr,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body style="font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #F8F9FA; padding: 20px; color: #1E293B;">
  <div style="max-width: 600px; margin: auto; background: white; border-radius: 16px; overflow: hidden; border: 1px solid #E2E8F0; box-shadow: 0 4px 12px rgba(0,0,0,0.06);">
    <div style="background: linear-gradient(135deg, #072454 0%, #0F3B82 100%); color: white; padding: 26px; text-align: center;">
      <h2 style="margin: 0; color: #F5B800; font-size: 22px;">Al Ijadah International School</h2>
      <p style="margin: 6px 0 0 0; font-size: 14px; color: #E2E8F0;">System Administration & Security Recovery</p>
    </div>
    <div style="padding: 26px;">
      <div style="background: #EFF6FF; border-left: 4px solid #0F3B82; padding: 12px 16px; border-radius: 6px; margin-bottom: 20px;">
        <strong style="color: #0F3B82; font-size: 14px;">Passcode Recovery Notice:</strong>
        <p style="margin: 4px 0 0 0; font-size: 13px; color: #334155;">An administrative passcode recovery request was initiated from the Al Ijadah Smart Pickup app.</p>
      </div>

      <p style="font-size: 14px; line-height: 1.5; color: #334155;">Below is your registered Admin & Settings Passcode to unlock the system settings screen:</p>

      <div style="background: #FFFBEB; border: 2px dashed #F5B800; border-radius: 12px; padding: 22px; text-align: center; margin: 24px 0;">
        <span style="font-size: 12px; color: #B45309; font-weight: bold; display: block; margin-bottom: 6px; letter-spacing: 1px;">YOUR ADMIN / SETTINGS PASSCODE:</span>
        <span style="font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0F3B82; font-family: monospace;">$passcode</span>
      </div>

      <p style="font-size: 13px; color: #64748B; line-height: 1.5;">You can use this passcode to open System Settings, configure security guards, or update your passcode anytime.</p>

      <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 20px 0;" />
      <p style="margin: 0; font-size: 11px; color: #94A3B8;"><strong>Recipient:</strong> $adminEmail | <strong>Timestamp:</strong> $timestampStr</p>
      <p style="margin: 4px 0 0 0; font-size: 11px; color: #DC2626;">If you did not request this recovery, someone attempted to access the system settings on a mobile device.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  /// HTML for Admin Registration Request
  String _generateAdminRegistrationEmailHtml({
    required String studentId,
    required String studentName,
    required String grade,
    required String supervisor,
    required String guardianName,
    required String parentMobile,
    required String parentEmail,
    required String approvalCode,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; background-color: #F8F9FA; padding: 20px; color: #1E293B;">
  <div style="max-width: 600px; margin: auto; background: white; border-radius: 12px; overflow: hidden; border: 1px solid #E2E8F0;">
    <div style="background: #0F3B82; color: white; padding: 20px; text-align: center;">
      <h2 style="margin: 0; color: #F5B800;">Al Ijadah International School</h2>
      <p style="margin: 5px 0 0 0; font-size: 14px;">Admin Portal: New Student Registration Request</p>
    </div>
    <div style="padding: 24px;">
      <p style="font-size: 14px;">A parent has submitted a registration request for pickup authorization:</p>
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Student ID:</td><td style="padding: 8px; font-weight: bold; color: #0F3B82;">$studentId</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Student Name:</td><td style="padding: 8px; font-weight: bold;">$studentName</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Grade / Class:</td><td style="padding: 8px;">$grade</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Supervisor:</td><td style="padding: 8px;">$supervisor</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Guardian Name:</td><td style="padding: 8px;">$guardianName</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Parent Mobile:</td><td style="padding: 8px;">$parentMobile</td></tr>
        <tr><td style="padding: 8px; color: #64748B; font-weight: bold;">Parent Email:</td><td style="padding: 8px;">$parentEmail</td></tr>
      </table>
      <div style="background: #FFFBEB; border: 2px dashed #F5B800; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 20px;">
        <p style="margin: 0 0 6px 0; font-size: 13px; color: #B45309; font-weight: bold;">OFFICIAL 6-DIGIT ACTIVATION CODE:</p>
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #0F3B82; font-family: monospace;">$approvalCode</span>
        <p style="margin: 10px 0 16px 0; font-size: 12px; color: #475569;">Send this 6-digit code to the parent ($parentEmail) so they can unlock their active digital pass in the app.</p>
        <a href="mailto:$parentEmail?subject=Al%20Ijadah%20Pass%20Approval%20Code%20for%20$studentName&body=Dear%20Parent%2C%0A%0AYour%20registration%20request%20for%20$studentName%20has%20been%20approved%20by%20the%20school%20administration.%0A%0AYour%206-digit%20pass%20activation%20code%20is%3A%20$approvalCode%0A%0APlease%20enter%20this%20code%20in%20your%20parent%20app%20to%20unlock%20your%20pickup%20pass.%0A%0ARegards%2C%0AAl%20Ijadah%20International%20School%20Administration" style="display: inline-block; background-color: #0F3B82; color: #FFFFFF; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: bold; font-size: 13px;">
          Reply to Parent with Activation Code ($approvalCode)
        </a>
      </div>
      <div style="background: #F8FAFC; padding: 12px; text-align: center; font-size: 11px; color: #64748B; border-top: 1px solid #E2E8F0;">
        ${AppConfig.schoolName} • Security Command Hotline: <strong>${AppConfig.schoolPhone}</strong>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// HTML for Parent Approval Code Email
  String _generateParentApprovalEmailHtml({
    required String studentName,
    required String studentId,
    required String approvalCode,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; background-color: #F8F9FA; padding: 20px; color: #1E293B;">
  <div style="max-width: 600px; margin: auto; background: white; border-radius: 12px; overflow: hidden; border: 1px solid #E2E8F0;">
    <div style="background: #0F3B82; color: white; padding: 24px; text-align: center;">
      <h2 style="margin: 0; color: #F5B800;">Al Ijadah International School</h2>
      <p style="margin: 6px 0 0 0; font-size: 14px;">Official Pickup Pass Verification & Approval</p>
    </div>
    <div style="padding: 24px;">
      <div style="background: #ECFDF5; border-left: 4px solid #10B981; padding: 12px 16px; border-radius: 6px; margin-bottom: 20px;">
        <strong style="color: #065F46;">Pass Approved:</strong> Your student registration for <strong>$studentName</strong> has been reviewed and approved by the administration.
      </div>
      <p style="font-size: 14px; line-height: 1.5;">To activate your dynamic pickup pass on your device, please open the <strong>Al Ijadah Parent App</strong>, tap your student's card, and enter your secure approval code:</p>
      <div style="background: #F8FAFC; border: 2px solid #0F3B82; border-radius: 10px; padding: 18px; text-align: center; margin: 24px 0;">
        <span style="font-size: 12px; color: #64748B; font-weight: bold; display: block; margin-bottom: 6px;">YOUR 6-DIGIT ACTIVATION CODE:</span>
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #0F3B82;">$approvalCode</span>
      </div>
      <p style="font-size: 13px; color: #64748B; line-height: 1.6;">Once entered, your dynamic 40-second auto-refreshing QR code and printable lanyard ID card will immediately activate.</p>
    </div>
    <div style="background: #F8FAFC; padding: 14px; text-align: center; font-size: 11px; color: #64748B; border-top: 1px solid #E2E8F0;">
      ${AppConfig.schoolName} • Security & Dispatch Office • Hotline: <strong>${AppConfig.schoolPhone}</strong>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generates royal blue & gold branded responsive HTML email template
  String _generateBrandedEmailHtml({
    required String studentName,
    required String guardianName,
    required String parentMobile,
    required String timestampStr,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pickup Confirmation - Al Ijadah International School</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #F8F9FA;
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      color: #1E293B;
    }
    .container {
      max-width: 600px;
      margin: 30px auto;
      background: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 10px 25px rgba(15, 59, 130, 0.08);
      border: 1px solid #E2E8F0;
    }
    .header {
      background: linear-gradient(135deg, #1B55B0 0%, #0F3B82 50%, #072454 100%);
      padding: 30px 20px;
      text-align: center;
      color: #FFFFFF;
    }
    .badge {
      display: inline-block;
      background: #F5B800;
      color: #0F3B82;
      font-weight: bold;
      font-size: 11px;
      padding: 4px 12px;
      border-radius: 20px;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin-bottom: 12px;
    }
    .title {
      font-size: 22px;
      font-weight: 700;
      margin: 0 0 6px 0;
      letter-spacing: -0.5px;
    }
    .subtitle {
      font-size: 13px;
      opacity: 0.85;
      margin: 0;
    }
    .content {
      padding: 30px 28px;
    }
    .alert-banner {
      background-color: #ECFDF5;
      border-left: 4px solid #10B981;
      padding: 14px 16px;
      border-radius: 8px;
      margin-bottom: 24px;
      font-size: 14px;
      color: #065F46;
      line-height: 1.5;
    }
    .details-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }
    .details-table td {
      padding: 12px 14px;
      border-bottom: 1px solid #F1F5F9;
      font-size: 14px;
    }
    .details-table td.label {
      color: #64748B;
      font-weight: 600;
      width: 40%;
    }
    .details-table td.value {
      color: #0F3B82;
      font-weight: 700;
    }
    .footer {
      background-color: #F8F9FA;
      padding: 20px 24px;
      text-align: center;
      font-size: 12px;
      color: #94A3B8;
      border-top: 1px solid #E2E8F0;
    }
    .footer a {
      color: #0F3B82;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">Official Security Alert</div>
      <h1 class="title">Al Ijadah International School</h1>
      <p class="subtitle">Smart Campus Student Pickup Verification System</p>
    </div>
    <div class="content">
      <div class="alert-banner">
        <strong>✓ Verified Safe Departure:</strong> Your student has been verified and picked up through the school security gate.
      </div>
      <table class="details-table">
        <tr>
          <td class="label">Student Name:</td>
          <td class="value">$studentName</td>
        </tr>
        <tr>
          <td class="label">Picked Up By:</td>
          <td class="value">$guardianName</td>
        </tr>
        <tr>
          <td class="label">Parent Contact Mobile:</td>
          <td class="value">$parentMobile</td>
        </tr>
        <tr>
          <td class="label">Verification Timestamp:</td>
          <td class="value">$timestampStr</td>
        </tr>
        <tr>
          <td class="label">Security Checkpoint:</td>
          <td class="value">Main Gate Scanner 01</td>
        </tr>
      </table>
      <p style="font-size: 13px; color: #64748B; line-height: 1.6; margin: 0;">
        If this pickup was unauthorized or you require immediate assistance, please contact the Al Ijadah Security Command Center at <strong>${AppConfig.schoolPhone}</strong> immediately.
      </p>
    </div>
    <div class="footer">
      <p style="margin: 0 0 6px 0;">${AppConfig.schoolName} • ${AppConfig.schoolAddress}</p>
      <p style="margin: 0;">Automated Dispatch Notification • Do not reply directly to this address</p>
    </div>
  </div>
</body>
</html>
''';
  }
}
