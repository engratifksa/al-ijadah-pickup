import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String label;

    final normalized = status.toUpperCase();
    if (normalized == 'APPROVED') {
      bg = AppTheme.verifiedGreenBg;
      fg = AppTheme.verifiedGreenDark;
      border = AppTheme.verifiedGreen.withValues(alpha: 0.4);
      icon = Icons.verified_rounded;
      label = compact ? 'APPROVED' : 'APPROVED PASS';
    } else if (normalized == 'REVOKED') {
      bg = AppTheme.alertRedBg;
      fg = AppTheme.alertRedDark;
      border = AppTheme.alertRed.withValues(alpha: 0.5);
      icon = Icons.block_rounded;
      label = compact ? 'REVOKED' : 'REVOKED PASS';
    } else if (normalized == 'REJECTED') {
      bg = AppTheme.alertRedBg;
      fg = AppTheme.alertRedDark;
      border = AppTheme.alertRed.withValues(alpha: 0.4);
      icon = Icons.cancel_rounded;
      label = 'REJECTED';
    } else {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
      icon = Icons.hourglass_top_rounded;
      label = compact ? 'PENDING' : 'PENDING APPROVAL';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 15, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
