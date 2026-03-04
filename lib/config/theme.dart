/// 앱 디자인 시스템: 색상 팔레트 및 테마 설정
///
/// AppColors: 앱 전체에서 사용하는 시맨틱 색상 상수
/// AppTheme: Material 3 기반 라이트 테마 설정
import 'package:flutter/material.dart';

/// 앱 전역 색상 팔레트
///
/// 배경, 텍스트, 상태(성공/경고/위험), 액센트 등
/// 시맨틱 이름으로 정의하여 일관된 UI를 유지한다.
class AppColors {
  static const bg = Color(0xFFF5EDF0);           // 앱 배경색 (연한 핑크 베이지)
  static const white = Color(0xFFFFFFFF);         // 순백색
  static const border = Color(0xFFE8E0E3);        // 테두리/구분선
  static const accent = Color(0xFF3B8DD9);        // 주요 강조색 (파란색)
  static const accentLight = Color(0xFF5CA5E8);   // 강조색 밝은 버전
  static const accentBg = Color(0xFFEBF3FD);      // 강조색 배경
  static const success = Color(0xFF00B894);       // 성공/완료 (초록)
  static const successBg = Color(0xFFE6F9F4);     // 성공 배경
  static const warning = Color(0xFFF39C12);       // 경고 (주황)
  static const warningBg = Color(0xFFFEF5E6);     // 경고 배경
  static const danger = Color(0xFFFF6B6B);        // 위험/에러 (빨강)
  static const dangerBg = Color(0xFFFFEEEE);      // 위험 배경
  static const text = Color(0xFF222222);          // 기본 텍스트
  static const textSecondary = Color(0xFF6B7280); // 보조 텍스트 (회색)
  static const textMuted = Color(0xFF9CA3AF);     // 비활성 텍스트 (연한 회색)
  static const tabInactive = Color(0xFF9CA3AF);   // 비활성 탭 색상
}

/// Material 3 기반 앱 테마 설정
///
/// DM Sans 폰트 사용, 라이트 모드만 지원.
/// AppBar, Text, Button, Input 등 주요 컴포넌트의 기본 스타일을 정의한다.
class AppTheme {
  static const String fontFamily = 'DMSans';

  /// 라이트 테마 데이터
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.white,
    ),
    // ── AppBar 스타일: 흰색 배경, 중앙 정렬 제목 ──
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
    // ── 텍스트 스타일 계층 (headlineLarge ~ bodySmall) ──
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
      headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
    // ── 기본 버튼 스타일: accent 배경, 둥근 모서리 ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    // ── 입력 필드 스타일: 흰색 배경, 둥근 테두리 ──
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
