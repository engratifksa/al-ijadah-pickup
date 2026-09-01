import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../services/encryption_service.dart';
import '../../services/smtp_email_service.dart';
import '../../widgets/student_photo_widget.dart';

class VerificationScreen extends StatefulWidget {
  final QrValidationResult validationResult;
  final StudentModel? student;

  const VerificationScreen({
    super.key,
    required this.validationResult,
    this.student,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _smtpService = SmtpEmailService();
  bool _isConfirming = false;
  bool _pickupConfirmed = false;

  StudentModel get effectiveStudent {
    if (widget.student != null) return widget.student!;
    final p = widget.validationResult.payload;
    return StudentModel(
      id: p?.studentId ?? 'AIS-PASS',
      name: (p != null && p.studentName.isNotEmpty) ? p.studentName : 'Student ${p?.studentId ?? ""}',
      grade: (p != null && p.grade.isNotEmpty) ? p.grade : 'Registered Student',
      supervisor: 'School Administrator',
      parentEmail: p?.parentEmail ?? '',
      parentMobile: p?.parentMobile ?? '',
      guardianName: (p != null && p.guardianName.isNotEmpty) ? p.guardianName : 'Parent / Guardian',
      status: p?.status ?? 'APPROVED',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get isSuccess =>
      widget.validationResult.isValid &&
      (widget.student != null || widget.validationResult.payload != null) &&
      effectiveStudent.isApproved;

  String get invalidReasonMessage {
    if (!widget.validationResult.isValid) {
      return widget.validationResult.message;
    }
    if (!effectiveStudent.isApproved) {
      return 'Security Alert: Student pass status is ${effectiveStudent.status}. Pickup authorization is not granted.';
    }
    return widget.validationResult.message;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $phoneNumber')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dialer error: $e')),
      );
    }
  }

  Future<void> _handleConfirmPickup() async {
    if (_isConfirming || _pickupConfirmed) return;

    final student = effectiveStudent;
    final payload = widget.validationResult.payload;
    final guardian = payload?.guardianName.isNotEmpty == true ? payload!.guardianName : student.guardianName;
    final mobile = payload?.parentMobile.isNotEmpty == true ? payload!.parentMobile : student.parentMobile;
    final email = payload?.parentEmail.isNotEmpty == true ? payload!.parentEmail : student.parentEmail;

    setState(() => _isConfirming = true);

    try {
      final result = await _smtpService.sendPickupConfirmation(
        parentEmail: email,
        parentMobile: mobile,
        studentName: student.name,
        guardianName: guardian,
        pickupTime: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        _pickupConfirmed = true;
      });

      _showConfirmationSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Pickup error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _showConfirmationSuccessDialog(EmailDispatchResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.verifiedGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.verifiedGreenDark, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pickup Confirmed!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.primaryRoyalBlue),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student ${widget.student?.name} has been marked as safely dispatched.',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.status == EmailDispatchStatus.sentDirectly
                          ? Icons.mark_email_read_rounded
                          : Icons.schedule_send_rounded,
                      color: result.status == EmailDispatchStatus.sentDirectly
                          ? AppTheme.verifiedGreenDark
                          : AppTheme.warningOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.message,
                        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Back to scanner
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRoyalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Scan Next Pass'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isSuccess ? _buildSuccessView(context) : _buildInvalidView(context),
    );
  }

  // ===================== SUCCESS GREEN VIEW =====================
  Widget _buildSuccessView(BuildContext context) {
    final student = effectiveStudent;
    final payload = widget.validationResult.payload;
    final guardian = payload?.guardianName.isNotEmpty == true ? payload!.guardianName : student.guardianName;
    final mobile = payload?.parentMobile.isNotEmpty == true ? payload!.parentMobile : student.parentMobile;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.verifiedGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security_rounded, size: 14, color: AppTheme.accentGold),
                        const SizedBox(width: 6),
                        Text(
                          'SECURITY CHECKPOINT 01',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // balance spacing
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // Verified Badge Header
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.verifiedGreenDark,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PASS VERIFIED & VALID',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Dynamic AES Token Authenticated (${widget.validationResult.ageSeconds}s ago)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Main Verification White Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          // Student Photo Portrait
                          Center(
                            child: Container(
                              width: 120,
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accentGold, width: 3.5),
                                color: const Color(0xFFF1F5F9),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryRoyalBlue.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _buildVerificationPhoto(student.photoPath),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Student Name & Grade
                          Text(
                            student.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryRoyalBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRoyalBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student.grade,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryRoyalBlue,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                          const SizedBox(height: 14),

                          // Verification Details Table
                          _buildDetailRow(
                            'Student ID:',
                            student.id,
                            Icons.badge_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Supervisor:',
                            student.supervisor,
                            Icons.assignment_ind_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Authorized Guardian:',
                            guardian,
                            Icons.family_restroom_rounded,
                            isBold: true,
                          ),
                          const SizedBox(height: 14),

                          // Parent Mobile with Quick Call Action
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRoyalBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.phone_rounded, color: AppTheme.primaryRoyalBlue, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Parent Contact Mobile',
                                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                      Text(
                                        mobile,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryDarkBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(mobile),
                                  icon: const Icon(Icons.call_rounded, size: 16),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.verifiedGreenDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Confirm Pickup Action Button (Triggers Direct SMTP)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConfirming ? null : _handleConfirmPickup,
                        icon: _isConfirming
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: AppTheme.primaryRoyalBlue, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.done_all_rounded, size: 24),
                        label: Text(
                          _pickupConfirmed
                              ? 'Pickup Dispatched ✓'
                              : 'Confirm Pickup & Notify Parent',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDarkBlue,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: AppTheme.primaryDarkBlue,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== INVALID / EXPIRED RED VIEW =====================
  Widget _buildInvalidView(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.alertGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'SECURITY WARNING',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Red Warning Shield
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.gpp_bad_rounded,
                        color: AppTheme.alertRedDark,
                        size: 58,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'INVALID OR EXPIRED PASS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      invalidReasonMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Instruction Alert Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.report_problem_rounded, color: AppTheme.alertRedDark, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'STAFF ACTION REQUIRED:',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.alertRedDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. DO NOT release the student.\n'
                            '2. Ask parent/guardian to open their live Al Ijadah Parent App (do not accept screenshots or old photos).\n'
                            '3. If dynamic code fails repeatedly, request national/residence ID and escort guardian to School Administration Office.',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textDark,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.support_agent_rounded, color: AppTheme.alertRedDark),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Admin Hotline: ${AppConfig.schoolPhone}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.alertRedDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Rescan Barcode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.alertRedDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPhoto(String? path) {
    return StudentPhotoWidget(
      photoPath: path,
      fit: BoxFit.cover,
      iconSize: 64,
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryRoyalBlue),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: isBold ? AppTheme.primaryRoyalBlue : AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
