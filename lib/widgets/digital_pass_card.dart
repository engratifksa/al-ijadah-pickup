import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/student_model.dart';
import '../models/qr_payload_model.dart';
import '../services/encryption_service.dart';
import '../services/pdf_generator_service.dart';
import 'al_ijadah_header.dart';
import 'status_badge.dart';
import 'student_photo_widget.dart';

class DigitalPassCard extends StatefulWidget {
  final StudentModel student;
  final VoidCallback? onRefresh;

  const DigitalPassCard({
    super.key,
    required this.student,
    this.onRefresh,
  });

  @override
  State<DigitalPassCard> createState() => _DigitalPassCardState();
}

class _DigitalPassCardState extends State<DigitalPassCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _encryptionService = EncryptionService();
  String _currentEncryptedQrToken = '';
  int _remainingSeconds = AppConfig.qrRefreshIntervalSeconds;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _generateDynamicQrToken();
    _startRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When parent switches back to app or unlocks screen, immediately refresh token
    if (state == AppLifecycleState.resumed) {
      _generateDynamicQrToken();
      _startRefreshTimer();
    }
  }

  @override
  void didUpdateWidget(covariant DigitalPassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _generateDynamicQrToken();
      _resetTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateDynamicQrToken() {
    final approvalToken = _encryptionService.generateApprovalSignature(
      widget.student.id,
      widget.student.status,
    );
    final payload = QrPayloadModel(
      studentId: widget.student.id,
      studentName: widget.student.name,
      grade: widget.student.grade,
      guardianName: widget.student.guardianName,
      parentMobile: widget.student.parentMobile,
      parentEmail: widget.student.parentEmail,
      status: widget.student.status,
      approvalToken: approvalToken,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _currentEncryptedQrToken = _encryptionService.encryptPayload(payload);
    });
  }

  void _startRefreshTimer() {
    _timer?.cancel();
    _remainingSeconds = AppConfig.qrRefreshIntervalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _generateDynamicQrToken();
        _remainingSeconds = AppConfig.qrRefreshIntervalSeconds;
        widget.onRefresh?.call();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _resetTimer() {
    _startRefreshTimer();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / AppConfig.qrRefreshIntervalSeconds;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Royal Blue Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.royalBlueGradient,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                children: [
                  const AlIjadahHeader(
                    compact: true,
                    showMotto: false,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PASS ID: ${widget.student.id}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDarkBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      StatusBadge(status: widget.student.status, compact: true),
                    ],
                  ),
                ],
              ),
            ),

            // Gold accent divider
            Container(height: 3, color: AppTheme.accentGold),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Student Photo & Core Info Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Photo Frame
                      Container(
                        width: 78,
                        height: 94,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.accentGold, width: 2.5),
                          color: const Color(0xFFF1F5F9),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _buildStudentPhoto(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryRoyalBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.student.grade,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryRoyalBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildCompactInfoRow(
                              Icons.person_pin_circle_rounded,
                              'Supervisor: ${widget.student.supervisor}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                  const SizedBox(height: 12),

                  // Authorized Guardians & Mobile
                  _buildDetailedInfoBox(),

                  const SizedBox(height: 20),

                  // Dynamic QR Section (Live Encrypted & Auto-refreshing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_clock_rounded, size: 16, color: AppTheme.primaryRoyalBlue),
                            const SizedBox(width: 6),
                            Text(
                              'DYNAMIC ENCRYPTED QR PASS',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryRoyalBlue,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // QR Code Container with Live Pulsing Security frame
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.2), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _currentEncryptedQrToken.isNotEmpty
                                ? QrImageView(
                                    data: _currentEncryptedQrToken,
                                    version: QrVersions.auto,
                                    size: 175,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppTheme.primaryRoyalBlue,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.circle,
                                      color: AppTheme.primaryDarkBlue,
                                    ),
                                  )
                                : const SizedBox(
                                    width: 175,
                                    height: 175,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Refresh Timer Bar & Indicator
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _remainingSeconds < 10 ? AppTheme.alertRed : AppTheme.accentGold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _remainingSeconds < 10
                                    ? AppTheme.alertRed.withValues(alpha: 0.12)
                                    : AppTheme.primaryRoyalBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 13,
                                    color: _remainingSeconds < 10 ? AppTheme.alertRed : AppTheme.primaryRoyalBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_remainingSeconds}s',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _remainingSeconds < 10 ? AppTheme.alertRed : AppTheme.primaryRoyalBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        Text(
                          'Live dynamic token auto-refreshes every ${AppConfig.qrRefreshIntervalSeconds}s (Anti-Screenshot Protection)',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions: Print / Export Lanyard Card PDF
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePrintPdf(context),
                      icon: const Icon(Icons.print_rounded, size: 19),
                      label: const Text('Print / Export Lanyard Pass (PDF)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRoyalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentPhoto() {
    return StudentPhotoWidget(
      photoPath: widget.student.photoPath,
      fit: BoxFit.cover,
      iconSize: 40,
    );
  }

  Widget _buildCompactInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow('Authorized Guardian:', widget.student.guardianName, Icons.family_restroom_rounded),
          const SizedBox(height: 8),
          _buildInfoRow('Parent Mobile:', widget.student.parentMobile, Icons.phone_android_rounded, isHighlight: true),
          const SizedBox(height: 8),
          _buildInfoRow('Registered Email:', widget.student.parentEmail, Icons.email_outlined),
          const SizedBox(height: 8),
          _buildInfoRow('School Hotline:', AppConfig.schoolPhone, Icons.support_agent_rounded),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: isHighlight ? AppTheme.accentGoldDark : AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight ? AppTheme.primaryRoyalBlue : AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePrintPdf(BuildContext context) async {
    try {
      await PdfGeneratorService.printPass(widget.student);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }
}
