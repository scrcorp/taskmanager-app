/// 앱 쉘(Shell) 레이아웃 — ShellRoute용 공통 레이아웃
///
/// GoRouter의 ShellRoute에서 사용하는 레이아웃 위젯.
/// 구조: AppHeader (상단) + child (본문) + BottomNav (하단)
/// 하단 네비게이션이 있는 모든 탭 화면(Home, Work, Clock, Schedule)에 적용.
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'app_header.dart';
import 'bottom_nav.dart';

/// 앱 쉘 레이아웃 위젯
class AppShell extends StatelessWidget {
  /// 현재 라우트의 화면 위젯 (ShellRoute의 child)
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const AppHeader(),
          Expanded(child: child),
          const BottomNav(),
        ],
      ),
    );
  }
}
