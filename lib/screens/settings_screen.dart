import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/database_helper.dart';
import '../services/smtp_email_service.dart';
import '../services/backup_restore_service.dart';
import 'admin/admin_student_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dbHelper = DatabaseHelper();
  final _smtpService = SmtpEmailService();
  final _backupService = BackupRestoreService();
  late TextEditingController _gmailUserController;
  late TextEditingController _gmailAppPasswordController;
  late TextEditingController _adminEmailController;
  late TextEditingController _schoolPhoneController;
  late TextEditingController _smtpHostController;
  late TextEditingController _smtpPortController;
  late TextEditingController _webGatewayController;
  late TextEditingController _guardPinController;
  late TextEditingController _settingsPinController;
  late TextEditingController _testEmailController;
  bool _mockSmtp = AppConfig.enableMockSmtpWhenOfflineOrEmpty;
  bool _isTestingSmtp = false;

  @override
  void initState() {
    super.initState();
    _gmailUserController = TextEditingController(text: AppConfig.smtpGmailUser);
    _gmailAppPasswordController = TextEditingController(text: AppConfig.smtpGmailAppPassword);
    _adminEmailController = TextEditingController(text: AppConfig.adminEmail);
    _schoolPhoneController = TextEditingController(text: AppConfig.schoolPhone);
    _smtpHostController = TextEditingController(text: AppConfig.smtpHost);
    _smtpPortController = TextEditingController(text: AppConfig.smtpPortSsl.toString());
    _webGatewayController = TextEditingController(text: AppConfig.webHttpGatewayUrl);
    _guardPinController = TextEditingController(text: AppConfig.guardPin);
    _settingsPinController = TextEditingController(text: AppConfig.settingsPin);
    _testEmailController = TextEditingController(text: AppConfig.smtpGmailUser);
  }

  @override
  void dispose() {
    _gmailUserController.dispose();
    _gmailAppPasswordController.dispose();
    _adminEmailController.dispose();
    _schoolPhoneController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _webGatewayController.dispose();
    _guardPinController.dispose();
    _settingsPinController.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    AppConfig.smtpGmailUser = _gmailUserController.text.trim();
    // Auto-strip spaces so whether user enters "abcd efgh ijkl mnop" or "abcdefghijklmnop", it works perfectly
    AppConfig.smtpGmailAppPassword = _gmailAppPasswordController.text.replaceAll(' ', '').trim();
    AppConfig.adminEmail = _adminEmailController.text.trim();
    AppConfig.schoolPhone = _schoolPhoneController.text.trim();
    AppConfig.smtpHost = _smtpHostController.text.trim();
    AppConfig.smtpPortSsl = int.tryParse(_smtpPortController.text.trim()) ?? 465;
    AppConfig.webHttpGatewayUrl = _webGatewayController.text.trim();
    AppConfig.enableMockSmtpWhenOfflineOrEmpty = _mockSmtp;
    if (_guardPinController.text.trim().isNotEmpty) {
      AppConfig.guardPin = _guardPinController.text.trim();
    }
    if (_settingsPinController.text.trim().isNotEmpty) {
      AppConfig.settingsPin = _settingsPinController.text.trim();
    }
    AppConfig.saveToPreferences();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.verifiedGreenDark,
        content: Text('Settings, Passcodes & Contact Info saved permanently!'),
      ),
    );
  }

  Future<void> _handleTestSmtp() async {
    _saveSettings();
    final toEmail = _testEmailController.text.trim();
    if (toEmail.isEmpty || !toEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Please enter a valid recipient email address for testing.'),
        ),
      );
      return;
    }

    setState(() => _isTestingSmtp = true);

    try {
      final result = await _smtpService.testSmtpConnection(recipientEmail: toEmail);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                result.isSuccessful ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: result.isSuccessful ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.isSuccessful ? 'SMTP Test Successful' : 'SMTP Test Report',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              result.message,
              style: GoogleFonts.outfit(fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingSmtp = false);
    }
  }

  Future<void> _handleResetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset & Reseed Database?'),
        content: const Text('This will reset local SQLite tables to the official demo students and clear email queue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRedDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset DB'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.clearDatabaseAndReseed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database re-seeded with demo students.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System & SMTP Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Direct SMTP Dispatch Configuration (Gmail)', Icons.mail_lock_rounded),
            const SizedBox(height: 8),
            Text(
              'Configures the zero-cost direct email notification engine for instant pickup alerts to parents.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _gmailUserController,
              decoration: const InputDecoration(
                labelText: 'School Gmail Sender Address',
                hintText: 'security@gmail.com',
                prefixIcon: Icon(Icons.email_rounded),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _gmailAppPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Google App Password (16 chars)',
                hintText: 'xxxx xxxx xxxx xxxx',
                prefixIcon: Icon(Icons.key_rounded),
                helperText: '16 characters. Enter with or without spaces (spaces are automatically removed)',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: 'School Administration Email (Alerts & Approvals)',
                hintText: 'admin@alijadah.edu.sa',
                prefixIcon: Icon(Icons.shield_outlined),
                helperText: 'New student registration alerts and pass approvals are sent here',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _schoolPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'School & Security Contact Phone Number',
                hintText: '+966 55 596 2300',
                prefixIcon: Icon(Icons.phone_in_talk_rounded),
                helperText: 'Displayed in parent notification emails, security hotline alerts, and ID cards',
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _smtpHostController,
                    decoration: const InputDecoration(
                      labelText: 'SMTP Host',
                      prefixIcon: Icon(Icons.dns_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _smtpPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SSL Port',
                      prefixIcon: Icon(Icons.lan_rounded),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _webGatewayController,
              decoration: const InputDecoration(
                labelText: 'Web / PWA Email Gateway URL (For iPhone/Web)',
                hintText: 'https://script.google.com/macros/s/.../exec',
                prefixIcon: Icon(Icons.cloud_sync_rounded),
                helperText: 'For iPhone/Web PWA: Google Apps Script Web App URL or REST webhook',
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fallback Simulation Mode',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Allows test dispatches when demo Gmail credentials are used',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _mockSmtp,
                    activeTrackColor: AppTheme.primaryRoyalBlue,
                    onChanged: (val) => setState(() => _mockSmtp = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Student Records & Pass Authority', Icons.manage_accounts_rounded),
            const SizedBox(height: 8),
            Text(
              'As Setting Admin, you have authority to view all student records, permanently delete records, or revoke/approve digital pickup passes.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded, color: AppTheme.primaryRoyalBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Roster & Passes',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Permanently delete records, revoke passes, or 1-click approve',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRoyalBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const AdminStudentManagementScreen()),
                        );
                      },
                      icon: const Icon(Icons.people_alt_rounded),
                      label: const Text('Manage Student Records & Revoke Passes'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Data Backup & Device Migration', Icons.cloud_sync_rounded),
            const SizedBox(height: 8),
            Text(
              'Easily backup student records and settings, or transfer your entire database to another mobile device (Android or iOS).',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.verifiedGreenDark.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.verifiedGreenDark, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cross-Device Backup & Restore',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Compatible across Android & iOS devices',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRoyalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _backupService.exportAndShareBackup(context),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Export Backup'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryRoyalBlue,
                            side: const BorderSide(color: AppTheme.primaryRoyalBlue),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _backupService.pickAndRestoreBackup(context),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Restore Backup'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentGoldDark,
                        side: const BorderSide(color: AppTheme.accentGoldDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _backupService.emailBackupToAdmin(context),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: Text('Email Backup to ${AppConfig.adminEmail}'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Security Passcodes & Access Control', Icons.admin_panel_settings_rounded),
            const SizedBox(height: 8),
            Text(
              'Set separate passcodes for security staff and administrators. Guards enter their passcode once to keep their session active.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _guardPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Security Guard Passcode',
                hintText: '••••',
                prefixIcon: Icon(Icons.security_rounded),
                helperText: '4-digit PIN for guards to unlock scanner session (persists until logged out)',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _settingsPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Admin & Settings Passcode',
                hintText: '••••',
                prefixIcon: Icon(Icons.lock_person_rounded),
                helperText: '4-digit master PIN required to open this System Settings screen',
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Settings & PIN'),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            _buildSectionHeader('Live Direct SMTP Delivery Test', Icons.mark_email_read_rounded),
            const SizedBox(height: 8),
            Text(
              'Send an immediate real test pickup notification email to verify your Google App Password and connection.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _testEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Test Recipient Email',
                      hintText: 'parent.test@gmail.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isTestingSmtp ? null : _handleTestSmtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGoldDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: _isTestingSmtp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_isTestingSmtp ? 'Sending...' : 'Send Test'),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            _buildSectionHeader('Database & Reset Options', Icons.storage_rounded),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _handleResetDatabase,
              icon: const Icon(Icons.restore_page_rounded, color: AppTheme.alertRedDark),
              label: Text(
                'Clear All Student Records (Clean Reset)',
                style: GoogleFonts.outfit(color: AppTheme.alertRedDark, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.alertRed),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryRoyalBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryRoyalBlue,
            ),
          ),
        ),
      ],
    );
  }
}
