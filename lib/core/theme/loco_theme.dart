import 'package:flutter/material.dart';

/// LOCO Design System Color Palette
/// Rule: LOCO = ORANGE + WHITE + RAIL + MOVEMENT
class LocoColors {
  // Primary Brand Orange
  static const Color orange = Color(0xFFFF5500);
  static const Color orangeDark = Color(0xFFE04A00);
  static const Color orangeLight = Color(0xFFFFF0E6);
  static const Color orangeSurface = Color(0xFFFFF0E6);
  static const Color orangeGlow = Color(0x33FF5500);

  // Canvas & Backgrounds (Dominant White & Warm Neutrals)
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF111827); // Deep near-black
  static const Color textSecondary = Color(0xFF4B5563); // Warm slate
  static const Color textMuted = Color(0xFF9CA3AF); // Subdued gray
  static const Color textOnOrange = Color(0xFFFFFFFF);

  // Railway Line Identity
  static const Color westernLine = Color(0xFFFF5500); // Western Railway (Orange)
  static const Color centralLine = Color(0xFFF59E0B); // Central Railway (Amber/Gold)
  static const Color harbourLine = Color(0xFF059669); // Harbour Railway (Emerald)
  static const Color transHarbour = Color(0xFF0284C7); // Trans-Harbour (Sky)

  // Status & Safety Indicators
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Crowd States
  static const Color crowdLow = Color(0xFF10B981);
  static const Color crowdModerate = Color(0xFFF59E0B);
  static const Color crowdHigh = Color(0xFFEA580C);
  static const Color crowdVeryHigh = Color(0xFFDC2626);
}

class LocoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: LocoColors.canvas,
      primaryColor: LocoColors.orange,
      colorScheme: const ColorScheme.light(
        primary: LocoColors.orange,
        onPrimary: LocoColors.white,
        secondary: LocoColors.textPrimary,
        surface: LocoColors.white,
        error: LocoColors.error,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: LocoColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: LocoColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LocoColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: LocoColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: LocoColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: LocoColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: LocoColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LocoColors.white,
        foregroundColor: LocoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LocoColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: LocoColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LocoColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LocoColors.orange,
          foregroundColor: LocoColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LocoColors.textPrimary,
          side: const BorderSide(color: LocoColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LocoColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LocoColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LocoColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LocoColors.orange, width: 2),
        ),
        hintStyle: const TextStyle(color: LocoColors.textMuted, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LocoColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: LocoColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
