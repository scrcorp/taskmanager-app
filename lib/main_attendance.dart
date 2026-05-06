/// Attendance Kiosk 엔트리 포인트 (HTMA — Hermesops Task Manager Attendance)
///
/// 매장 공용 태블릿 단말 전용 빌드. JWT 흐름을 거치지 않고
/// 진입 즉시 AttendanceShellScreen 으로 부팅한다.
///
/// Kiosk Lock 은 일단 비활성화 (Samsung 등 일부 기기에서 IME 차단/재핀
/// 동작이 부작용 일으킴). 관련 유틸 (KioskLock/KioskIntent/KioskEscapeWrapper)
/// 코드는 그대로 두고 호출만 안 함 — 추후 재활성화 가능.
///
/// 빌드:
///   flutter build apk --flavor attendance{dev|staging|production} \
///     -t lib/main_attendance.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/theme.dart';
import 'screens/attendance/attendance_shell_screen.dart';
import 'widgets/flavor_badge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 가로 고정 (태블릿 kiosk) — manifest 의 sensorLandscape 와 함께 강제.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 화면 항상 켜짐
  await WakelockPlus.enable();

  // 시스템 바 보이기 (immersiveSticky 는 IME 차단 부작용으로 제외)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: AttendanceKioskApp()));
}

class AttendanceKioskApp extends StatelessWidget {
  const AttendanceKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          FlavorBadgeOverlay(child: child ?? const SizedBox.shrink()),
      home: const AttendanceShellScreen(),
    );
  }
}
