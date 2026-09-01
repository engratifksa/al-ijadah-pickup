import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../services/database_helper.dart';
import '../../services/encryption_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/smtp_email_service.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/status_badge.dart';
import 'registration_screen.dart';

class DigitalCardScreen extends StatefulWidget {
  final StudentModel student;

  const DigitalCardScreen({super.key, required this.student});

  @override
  State<DigitalCardScreen> createState() => _DigitalCardScreenState();
}

class _DigitalCardScreenState extends State<DigitalCardScreen> {
  late StudentModel _currentStudent;
  final _dbHelper = DatabaseHelper();
  final _encryptionService = EncryptionService();
  final _smtpService = SmtpEmailService();
  final _codeController = TextEditingController();
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refreshStudent() async {
    final fresh = await _dbHelper.getStudentById(_currentStudent.id);
    if (fresh != null && mounted) {
      setState(() => _currentStudent = fresh);
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _currentStudent.isApproved ? 'PENDING_APPROVAL' : 'APPROVED';
    await _dbHelper.updateStudentStatus(_currentStudent.id, newStatus);
    await _refreshStudent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pass status updated to: $newStatus')),
    );
  }

  void _verifyAndUnlockWithCode(String code) async {
    if (code.trim().isEmpty) return;

    final isValid = _encryptionService.verifyApprovalUnlockCode(_currentStudent.id, code);
    if (isValid) {
      await _dbHelper.updateStudentStatus(_currentStudent.id, 'APPROVED');
      await _refreshStudent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.verifiedGreenDark,
          content: Text('Code Verified! Digital Pickup Pass Unlocked successfully!'),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Invalid Activation Code. Please check the code in your email.'),
        ),
      );
    }
  }

  Future<void> _sendApprovalCodeEmail() async {
    setState(() => _isSendingEmail = true);
    final code = _encryptionService.generateApprovalUnlockCode(_currentStudent.id);

    final sent = await _smtpService.sendParentApprovalCodeEmail(
      parentEmail: _currentStudent.parentEmail,
      studentName: _currentStudent.name,
      studentId: _currentStudent.id,
      approvalCode: code,
    );

    if (mounted) {
      setState(() => _isSendingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: sent ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
          content: Text(
            sent
                ? 'Approval notification sent to ${_currentStudent.parentEmail}! Please check your email inbox.'
                : 'Failed to send email. Check SMTP settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStudent.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Student Details',
            onPressed: () async {
              final updated = await Navigator.push<StudentModel>(
                context,
                MaterialPageRoute(
                  builder: (ctx) => RegistrationScreen(existingStudent: _currentStudent),
                ),
              );
              if (updated != null) {
                _refreshStudent();
              }
            },
          ),
          if (_currentStudent.isApproved)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export Lanyard PDF',
              onPressed: () => PdfGeneratorService.printPass(_currentStudent),
            ),
          // Setting Admin Pass Authority Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Admin Pass Authority',
            onSelected: (val) {
              if (val == 'REVOKE') {
                _adminRevokePass();
              } else if (val == 'APPROVE') {
                _adminDirectApprovePass();
              } else if (val == 'DELETE') {
                _adminDeleteStudent();
              }
            },
            itemBuilder: (ctx) => [
              if (_currentStudent.isApproved)
                const PopupMenuItem(
                  value: 'REVOKE',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: AppTheme.alertRed, size: 18),
                      SizedBox(width: 8),
                      Text('Admin: Revoke Pass', style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'APPROVE',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: AppTheme.verifiedGreenDark, size: 18),
                      SizedBox(width: 8),
                      Text('Admin: Approve Pass', style: TextStyle(color: AppTheme.verifiedGreenDark, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'DELETE',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: AppTheme.alertRed, size: 18),
                    SizedBox(width: 8),
                    Text('Admin: Delete Student', style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            if (_currentStudent.isApproved) ...[
              DigitalPassCard(
                student: _currentStudent,
                onRefresh: () => setState(() {}),
              ),
            ] else if (_currentStudent.isRevoked) ...[
              _buildRevokedPassCard(),
            ] else ...[
              // Locked State for Pending Passes with Code Entry
              _buildPendingApprovalBanner(),
            ],

            const SizedBox(height: 16),

            // Quick Edit Profile Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push<StudentModel>(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => RegistrationScreen(existingStudent: _currentStudent),
                    ),
                  );
                  if (updated != null) {
                    _refreshStudent();
                  }
                },
                icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryRoyalBlue),
                label: Text(
                  'Edit Student Data & Photo',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryRoyalBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryRoyalBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            ),
            child: const Icon(Icons.mark_email_unread_rounded, size: 32, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 14),
          Text(
            'Pass Pending Email Approval',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryRoyalBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A registration request for ${_currentStudent.name} (${_currentStudent.grade}) has been emailed to the school administration. Once approved, you will receive an official activation code in your email.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          const StatusBadge(status: 'PENDING_APPROVAL'),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 14),

          // Code Entry Field
          Text(
            'Enter the 6-digit activation code sent to your email:',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryRoyalBlue),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: '6-DIGIT CODE',
                    hintStyle: GoogleFonts.outfit(fontSize: 12, letterSpacing: 1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _verifyAndUnlockWithCode(_codeController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.verifiedGreenDark,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: const Text('Unlock Pass'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevokedPassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.alertRed.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.alertRedBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.alertRed, width: 2),
            ),
            child: const Icon(Icons.block_rounded, size: 34, color: AppTheme.alertRed),
          ),
          const SizedBox(height: 14),
          Text(
            'Pickup Pass Revoked',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.alertRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The digital pickup pass for ${_currentStudent.name} (${_currentStudent.grade}) has been revoked by school administration.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          const StatusBadge(status: 'REVOKED'),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Dynamic QR code generation is suspended for security reasons. Pickups using this pass will be rejected at security gates.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.verifiedGreenDark,
              side: const BorderSide(color: AppTheme.verifiedGreenDark),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: _adminDirectApprovePass,
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('Admin: Re-Approve Pass', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _promptAdminPin() async {
    final pinController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryRoyalBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin Authorization',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Setting Admin Passcode to perform this action.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Admin Passcode',
                hintText: '••••',
                prefixIcon: const Icon(Icons.lock_person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, val.trim() == AppConfig.settingsPin);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRoyalBlue),
            onPressed: () => Navigator.pop(ctx, pinController.text.trim() == AppConfig.settingsPin),
            child: const Text('Authorize'),
          ),
        ],
      ),
    );

    if (ok != true && pinController.text.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Access Denied: Incorrect Admin Passcode'),
        ),
      );
    }
    return ok == true;
  }

  Future<void> _adminRevokePass() async {
    final authorized = await _promptAdminPin();
    if (!authorized || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppTheme.alertRed),
            const SizedBox(width: 10),
            Text('Revoke Pass?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke the pickup pass for ${_currentStudent.name}?\n\nThe dynamic QR pass will immediately stop functioning.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Pass'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.updateStudentStatus(_currentStudent.id, 'REVOKED');
      await _refreshStudent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Pickup pass for ${_currentStudent.name} has been revoked.'),
        ),
      );
    }
  }

  Future<void> _adminDirectApprovePass() async {
    final authorized = await _promptAdminPin();
    if (!authorized || !mounted) return;

    await _dbHelper.updateStudentStatus(_currentStudent.id, 'APPROVED');
    await _refreshStudent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.verifiedGreenDark,
        content: Text('Pickup pass for ${_currentStudent.name} is now approved and active!'),
      ),
    );
  }

  Future<void> _adminDeleteStudent() async {
    final authorized = await _promptAdminPin();
    if (!authorized || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppTheme.alertRed),
            const SizedBox(width: 10),
            Text('Delete Student?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${_currentStudent.name} (ID: ${_currentStudent.id})?\n\nThis cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteStudent(_currentStudent.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryDarkBlue,
          content: Text('${_currentStudent.name}\'s record has been deleted.'),
        ),
      );
      Navigator.pop(context);
    }
  }
}
