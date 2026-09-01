import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/database_helper.dart';
import '../services/smtp_email_service.dart';
import '../widgets/al_ijadah_header.dart';
import 'parent/student_list_screen.dart';
import 'parent/registration_screen.dart';
import 'scanner/scanner_screen.dart';
import 'scanner/email_queue_screen.dart';
import 'settings_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _dbHelper = DatabaseHelper();
  final _smtpService = SmtpEmailService();

  int _approvedCount = 0;
  int _pendingCount = 0;
  int _failedAdminAttempts = 0;
  DateTime? _adminLockoutUntil;
  int _failedGuardAttempts = 0;
  DateTime? _guardLockoutUntil;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final students = await _dbHelper.getAllStudents();
    await _smtpService.updatePendingCount();
    if (mounted) {
      setState(() {
        _approvedCount = students.where((s) => s.isApproved).length;
        _pendingCount = students.where((s) => s.isPending).length;
      });
    }
  }

  /// Prompts for Security Guard Passcode only if session is not currently active
  Future<bool> _promptGuardPin() async {
    if (AppConfig.isGuardSessionActive) {
      return true;
    }

    if (_guardLockoutUntil != null && DateTime.now().isBefore(_guardLockoutUntil!)) {
      final secondsLeft = _guardLockoutUntil!.difference(DateTime.now()).inSeconds + 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Too many failed attempts. Security lockout active for $secondsLeft more seconds.'),
        ),
      );
      return false;
    }

    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.verifiedGreenDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.security_rounded, color: AppTheme.verifiedGreenDark, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Security Guard Login',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Security Guard Passcode. Once logged in, your session remains active until you explicitly log out.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Security Guard Passcode',
                hintText: '••••',
                prefixIcon: const Icon(Icons.pin_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, val.trim() == AppConfig.guardPin);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.verifiedGreenDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx, pinController.text.trim() == AppConfig.guardPin);
            },
            child: const Text('Log In Session'),
          ),
        ],
      ),
    );

    if (result == true) {
      _failedGuardAttempts = 0;
      await AppConfig.loginGuard();
      if (mounted) setState(() {});
      return true;
    } else if (result == false && pinController.text.isNotEmpty) {
      _failedGuardAttempts++;
      if (_failedGuardAttempts >= 5) {
        _guardLockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failedGuardAttempts = 0;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRedDark,
            content: Text(
              _guardLockoutUntil != null && DateTime.now().isBefore(_guardLockoutUntil!)
                  ? 'Too many failed attempts. Security lockout active for 30 seconds.'
                  : 'Access Denied: Incorrect Security Guard Passcode',
            ),
          ),
        );
      }
    }
    return false;
  }

  /// Prompts for Admin & Settings Master Passcode with Email Recovery Option
  Future<bool> _promptSettingsPin() async {
    if (_adminLockoutUntil != null && DateTime.now().isBefore(_adminLockoutUntil!)) {
      final secondsLeft = _adminLockoutUntil!.difference(DateTime.now()).inSeconds + 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Too many failed attempts. Admin security lockout active for $secondsLeft more seconds.'),
        ),
      );
      return false;
    }

    final pinController = TextEditingController();
    bool isRecovering = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRoyalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryRoyalBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Admin Authorization',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Admin & Settings Passcode to manage system configuration, passcodes, and Gmail credentials.',
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isRecovering
                      ? null
                      : () async {
                          setDialogState(() => isRecovering = true);
                          final sent = await _smtpService.sendAdminPasscodeRecoveryEmail(
                            adminEmail: AppConfig.adminEmail,
                            passcode: AppConfig.settingsPin,
                          );
                          setDialogState(() => isRecovering = false);

                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: sent ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
                                content: Text(
                                  sent
                                      ? 'Passcode recovery email sent to ${AppConfig.maskedAdminEmail}! Please check your email inbox.'
                                      : 'Failed to send recovery email. Check network or Gmail credentials.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: isRecovering
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.mark_email_unread_outlined, size: 16, color: AppTheme.primaryRoyalBlue),
                  label: Text(
                    isRecovering ? 'Sending Passcode...' : 'Forgot Passcode? Email to Admin',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryRoyalBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRoyalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx, pinController.text.trim() == AppConfig.settingsPin);
              },
              child: const Text('Access Settings'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _failedAdminAttempts = 0;
      return true;
    } else if (result == false && pinController.text.isNotEmpty) {
      _failedAdminAttempts++;
      if (_failedAdminAttempts >= 5) {
        _adminLockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failedAdminAttempts = 0;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRedDark,
            content: Text(
              _adminLockoutUntil != null && DateTime.now().isBefore(_adminLockoutUntil!)
                  ? 'Too many failed attempts. Admin security lockout active for 30 seconds.'
                  : 'Access Denied: Incorrect Admin Passcode',
            ),
          ),
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Al Ijadah Smart Pickup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'System Settings (Admin Passcode Required)',
            onPressed: () async {
              final ok = await _promptSettingsPin();
              if (!ok || !mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
              _loadStats();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Hero Banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.royalBlueGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: const EdgeInsets.only(top: 16, bottom: 24, left: 20, right: 20),
              child: Column(
                children: [
                  const AlIjadahHeader(
                    compact: false,
                    showMotto: true,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroStat('$_approvedCount', 'Active Passes', Icons.verified_rounded, AppTheme.accentGold),
                        Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
                        _buildHeroStat('$_pendingCount', 'Pending Approval', Icons.hourglass_top_rounded, Colors.orangeAccent),
                        Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
                        ValueListenableBuilder<int>(
                          valueListenable: _smtpService.pendingQueueCount,
                          builder: (ctx, queueCount, _) => _buildHeroStat(
                            '$queueCount',
                            'Email Queue',
                            Icons.mail_rounded,
                            queueCount > 0 ? AppTheme.accentGold : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Select Operational Mode Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Operational Flow',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryRoyalBlue,
                    ),
                  ),
                  Text(
                    'Choose your role to access digital passes or security verification',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 18),

                  // 1. PARENT APP FLOW CARD
                  _buildFlowCard(
                    context: context,
                    title: 'Parent & Guardian Portal',
                    subtitle: 'Register children, display dynamic 40s encrypted QR pass, and print high-res lanyard cards.',
                    icon: Icons.family_restroom_rounded,
                    accentColor: AppTheme.primaryRoyalBlue,
                    badgeText: 'PARENT FLOW',
                    features: [
                      'Offline dynamic AES-256 QR code generator',
                      'Auto-refreshing 40-second anti-fraud timer',
                      'High-resolution PDF lanyard ID pass printer',
                    ],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const StudentListScreen()),
                      );
                      _loadStats();
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. SCHOOL SCANNER APP FLOW CARD
                  _buildFlowCard(
                    context: context,
                    title: 'School Security Scanner',
                    subtitle: AppConfig.isGuardSessionActive
                        ? 'Active Guard Session. Tap to open camera scanner immediately without passcode.'
                        : 'Instant offline QR camera scan, student verification overlay, and automated Direct SMTP email dispatch.',
                    icon: Icons.qr_code_scanner_rounded,
                    accentColor: AppTheme.verifiedGreenDark,
                    badgeText: AppConfig.isGuardSessionActive ? 'SESSION ACTIVE (UNLOCKED)' : 'SECURITY & STAFF',
                    features: [
                      'Real-time offline camera barcode recognition',
                      'High-contrast Green Verified / Red Alert display',
                      'Zero-cost Direct SMTP (Gmail) pickup notification',
                      'Single passcode login: session persists until logout',
                    ],
                    onTap: () async {
                      final ok = await _promptGuardPin();
                      if (!ok || !mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
                      );
                      _loadStats();
                      if (mounted) setState(() {});
                    },
                  ),

                  if (AppConfig.isGuardSessionActive) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await AppConfig.logoutGuard();
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppTheme.primaryDarkBlue,
                                    content: Text('Security guard session logged out successfully.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 16, color: AppTheme.alertRed),
                            label: Text(
                              'Log Out Guard Session',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.alertRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Quick Action Utility Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionBtn(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'New Student',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const RegistrationScreen()),
                            );
                            _loadStats();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionBtn(
                          icon: Icons.outgoing_mail,
                          title: 'Email Queue',
                          onTap: () async {
                            final ok = await _promptGuardPin();
                            if (!ok || !mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const EmailQueueScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRoyalBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor.withOpacity(0.85), accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryRoyalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textLight),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 13, color: accentColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f,
                            style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryRoyalBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryRoyalBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
