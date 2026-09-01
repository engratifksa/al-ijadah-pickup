import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class AlIjadahHeader extends StatelessWidget {
  final bool compact;
  final bool showMotto;
  final Color? backgroundColor;
  final Color? textColor;

  const AlIjadahHeader({
    super.key,
    this.compact = false,
    this.showMotto = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = textColor ?? AppTheme.primaryRoyalBlue;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 16,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official School Crest Emblem Image
              Container(
                width: compact ? 38 : 50,
                height: compact ? 38 : 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRoyalBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(compact ? 4 : 6),
                child: Image.asset(
                  'assets/images/al_ijadah_crest.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    color: AppTheme.primaryRoyalBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدرسة الإجادة العالمية',
                      style: GoogleFonts.notoKufiArabic(
                        fontSize: compact ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGoldDark,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      AppConfig.schoolName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: compact ? 13 : 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showMotto && !compact) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Text(
                AppConfig.schoolMotto,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryRoyalBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
