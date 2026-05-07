/// Attendance 키오스크 앱 진입점.
///
/// 태블릿 기기에 APK로 배포되어 device-token 기반 self-service auth로 동작.
/// staff 앱과 분리된 별개 entrypoint — JWT 인증/라우터를 사용하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import 'screens/attendance/attendance_shell_screen.dart';

const _appEnv = String.fromEnvironment('APP_ENV');
const _appTitle = _appEnv == 'production'
    ? 'HTM Attendance'
    : _appEnv == 'staging'
        ? '[STG] HTM Attendance'
        : '[DEV] HTM Attendance';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 키오스크 모드 초기화 — 영속된 임시해제 타이머 복구
  await KioskIntent.armTimerIfPending();
  // 가로 고정 (태블릿 키오스크)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: AttendanceApp()));
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      theme: AppTheme.light,
      home: const AttendanceShellScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
