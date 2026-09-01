import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../models/qr_payload_model.dart';
import '../../services/database_helper.dart';
import '../../services/encryption_service.dart';
import '../../services/smtp_email_service.dart';
import '../../widgets/al_ijadah_header.dart';
import 'email_queue_screen.dart';
import 'verification_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final _encryptionService = EncryptionService();
  final _dbHelper = DatabaseHelper();
  final _smtpService = SmtpEmailService();

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _smtpService.updatePendingCount();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processScannedToken(rawValue);
        break;
      }
    }
  }

  Future<void> _processScannedToken(String token, {int? simulatedNowEpochMs}) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Decrypt & validate time token
      final validationResult = _encryptionService.decryptAndValidate(
        token,
        simulatedNowEpochMs: simulatedNowEpochMs,
      );

      StudentModel? student;
      final payload = validationResult.payload;
      if (payload != null && payload.studentId.isNotEmpty) {
        student = await _dbHelper.getStudentById(payload.studentId);

        // Cross-Device Auto-Sync:
        // If student is not in this device's local database (e.g. registered on parent device),
        // verify approval signature and auto-ingest into local database
        if (student == null && validationResult.isValid) {
          final isSignatureValid = _encryptionService.verifyApprovalSignature(
            payload.studentId,
            payload.status,
            payload.approvalToken,
          );

          if (isSignatureValid) {
            student = StudentModel(
              id: payload.studentId,
              name: payload.studentName.isNotEmpty ? payload.studentName : 'Student ${payload.studentId}',
              grade: payload.grade.isNotEmpty ? payload.grade : 'General',
              supervisor: 'School Administrator',
              parentEmail: payload.parentEmail,
              parentMobile: payload.parentMobile,
              guardianName: payload.guardianName,
              status: payload.status.isNotEmpty ? payload.status : 'APPROVED',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            try {
              await _dbHelper.insertStudent(student);
              debugPrint('[Scanner] Auto-synced cross-device student: ${student.id} (${student.name})');
            } catch (e) {
              debugPrint('[Scanner] Note on auto-sync: $e');
            }
          }
        }

        // Anti-Replay: Mark this dynamic token instance as consumed immediately
        if (validationResult.isValid) {
          _encryptionService.markTokenConsumed(payload);
        }
      }

      if (!mounted) return;

      // Navigate to full-screen verification result
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => VerificationScreen(
            validationResult: validationResult,
            student: student,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing error: $e')),
      );
    } finally {
      // Resume scanning after returning
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryRoyalBlue,
        title: const Text('Security Scanner Gate'),
        actions: [
          // Torch Toggle
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Flashlight',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          // Email Queue Status
          ValueListenableBuilder<int>(
            valueListenable: _smtpService.pendingQueueCount,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mark_email_unread_rounded),
                    tooltip: 'Offline Email Queue',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const EmailQueueScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentGold,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDarkBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Guard Logout Action Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.accentGold),
            tooltip: 'Log Out Guard Session',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTheme.alertRed),
                      const SizedBox(width: 10),
                      Text(
                        'Log Out Guard?',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  content: Text(
                    'Ending your security guard session will require entering your passcode again on next access.',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AppConfig.logoutGuard();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.primaryDarkBlue,
                    content: Text('Guard session ended. You are now logged out.'),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Viewfinder Target Overlay
          _buildScannerOverlay(),

          // Bottom Control & Test Simulator Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Colors.black.withOpacity(0.55),
          child: const AlIjadahHeader(
            compact: true,
            showMotto: false,
            textColor: Colors.white,
          ),
        ),
        const Spacer(),
        // Center Target Frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.accentGold, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Corner accents
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                ),
                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentGold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Align Dynamic QR Pass inside square',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showManualTestSimulatorModal(context),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Test Simulation Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRoyalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _scannerController.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceSlate,
              foregroundColor: AppTheme.primaryRoyalBlue,
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  /// Test Simulation Modal allowing direct verification of sample students (Valid, Expired, Tampered)
  void _showManualTestSimulatorModal(BuildContext context) async {
    final students = await _dbHelper.getAllStudents();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verification Simulator',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryRoyalBlue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'Simulate instant scans without physical camera pointing:',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              // Valid Students List
              Text(
                'SIMULATE VALID SCANS (CURRENT DYNAMIC CODE):',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.verifiedGreenDark),
              ),
              const SizedBox(height: 8),
              ...students.take(3).map((student) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.verifiedGreenBg,
                    child: Icon(Icons.check_circle_outline, color: AppTheme.verifiedGreenDark, size: 20),
                  ),
                  title: Text(student.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  subtitle: Text('${student.grade} • ${student.parentMobile}', style: GoogleFonts.outfit(fontSize: 11)),
                  trailing: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryRoyalBlue),
                  onTap: () {
                    Navigator.pop(ctx);
                    final payload = QrPayloadModel(
                      studentId: student.id,
                      guardianName: student.guardianName,
                      parentMobile: student.parentMobile,
                      parentEmail: student.parentEmail,
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    );
                    final token = _encryptionService.encryptPayload(payload);
                    _processScannedToken(token);
                  },
                );
              }),

              const Divider(height: 24),

              // Invalid / Expired Test Cases
              Text(
                'SIMULATE SECURITY WARNING CASES:',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.alertRedDark),
              ),
              const SizedBox(height: 8),

              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.alertRedBg,
                  child: Icon(Icons.timer_off_rounded, color: AppTheme.alertRedDark, size: 20),
                ),
                title: Text('Expired Screenshot Token (>75s old)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                subtitle: const Text('Simulates parent presenting a stale static screenshot'),
                onTap: () {
                  Navigator.pop(ctx);
                  final payload = QrPayloadModel(
                    studentId: students.isNotEmpty ? students.first.id : 'AIS-2026-1082',
                    guardianName: 'Dr. Faisal Al-Mansoor',
                    parentMobile: '+966 50 123 4567',
                    parentEmail: 'parent.zaid@example.com',
                    timestamp: DateTime.now().millisecondsSinceEpoch - 120000, // 2 minutes ago
                  );
                  final token = _encryptionService.encryptPayload(payload);
                  _processScannedToken(token);
                },
              ),

              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.alertRedBg,
                  child: Icon(Icons.lock_open_rounded, color: AppTheme.alertRedDark, size: 20),
                ),
                title: Text('Tampered / Corrupt QR Token', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                subtitle: const Text('Simulates unrecognized barcode or invalid encryption key'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processScannedToken('INVALID_TAMPERED_TOKEN_XYZ_12345');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
