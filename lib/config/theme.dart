import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF5EDF0);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8E0E3);
  static const accent = Color(0xFF3B8DD9);
  static const accentLight = Color(0xFF5CA5E8);
  static const accentBg = Color(0xFFEBF3FD);
  static const success = Color(0xFF00B894);
  static const successBg = Color(0xFFE6F9F4);
  static const warning = Color(0xFFF39C12);
  static const warningBg = Color(0xFFFEF5E6);
  static const danger = Color(0xFFFF6B6B);
  static const dangerBg = Color(0xFFFFEEEE);
  static const text = Color(0xFF222222);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const tabInactive = Color(0xFF9CA3AF);
}

class AppTheme {
  static const String fontFamily = 'DMSans';

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
      headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    dividerColor: AppColors.border,
  );
}
