import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette
  static const Color primaryRoyalBlue = Color(0xFF0F3B82);
  static const Color primaryDarkBlue = Color(0xFF072454);
  static const Color primaryLightBlue = Color(0xFF1B55B0);
  
  static const Color accentGold = Color(0xFFF5B800);
  static const Color accentGoldDark = Color(0xFFD99E00);
  static const Color accentGoldLight = Color(0xFFFFD54F);

  static const Color backgroundOffWhite = Color(0xFFF8F9FA);
  static const Color cardFill = Color(0xFFFFFFFF);
  static const Color surfaceSlate = Color(0xFFEDF2F7);

  // Status & Verification Colors
  static const Color verifiedGreen = Color(0xFF10B981);
  static const Color verifiedGreenDark = Color(0xFF047857);
  static const Color verifiedGreenBg = Color(0xFFECFDF5);

  static const Color alertRed = Color(0xFFEF4444);
  static const Color alertRedDark = Color(0xFFB91C1C);
  static const Color alertRedBg = Color(0xFFFEF2F2);

  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient royalBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLightBlue, primaryRoyalBlue, primaryDarkBlue],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGoldLight, accentGold, accentGoldDark],
  );

  static const LinearGradient verifiedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF064E3B)],
  );

  static const LinearGradient alertGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF7F1D1D)],
  );

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: textDark,
      displayColor: textDark,
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      scaffoldBackgroundColor: backgroundOffWhite,
      primaryColor: primaryRoyalBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryRoyalBlue,
        secondary: accentGold,
        surface: cardFill,
        error: alertRed,
        onPrimary: Colors.white,
        onSecondary: textDark,
        onSurface: textDark,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryRoyalBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardFill,
        elevation: 2.5,
        shadowColor: primaryRoyalBlue.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRoyalBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryRoyalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: alertRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: textLight, fontSize: 14),
      ),
    );
  }
}
