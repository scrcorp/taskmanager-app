/// Attendance Kiosk 엔트리 포인트 (TMA — TaskManager Attendance)
///
/// 매장 공용 태블릿 단말 전용 빌드. JWT 흐름을 거치지 않고
/// 진입 즉시 AttendanceShellScreen 으로 부팅한다.
///
/// 빌드:
///   flutter build apk --flavor attendance -t lib/main_attendance.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/theme.dart';
import 'screens/attendance/attendance_shell_screen.dart';
import 'utils/attendance_device_storage.dart';
import 'utils/kiosk_escape_wrapper.dart';
import 'utils/kiosk_intent.dart';
import 'utils/kiosk_lock.dart';
import 'widgets/flavor_badge.dart';

/// 키오스크 잠금이 활성화돼야 하는지 판단.
///
/// 등록된 기기(= token + access code 모두 보유) 인 경우에만 lock.
/// 둘 중 하나라도 없으면 Register 화면에서 dead-end 가 되거나
/// 해제 불가능 상태가 되므로 절대 잠그지 않는다.
Future<bool> shouldLockKiosk() async {
  if (!await KioskIntent.isEnabled()) return false;
  final token = await AttendanceDeviceStorage.getToken();
  if (token == null || token.isEmpty) return false;
  final code = await AttendanceDeviceStorage.getAccessCode();
  return code != null && code.isNotEmpty;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 가로 고정 (태블릿 kiosk)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 화면 항상 켜짐
  await WakelockPlus.enable();

  // 상태바 숨김 (몰입형)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 영속된 자동 재잠금 예약이 있으면 in-memory Timer 재무장
  await KioskIntent.armTimerIfPending();

  // 키오스크 잠금 — 등록된 기기(access code 있음) + intent ON 인 경우에만
  if (await shouldLockKiosk()) {
    await KioskLock.start();
  }

  runApp(const ProviderScope(child: AttendanceKioskApp()));
}

class AttendanceKioskApp extends StatefulWidget {
  const AttendanceKioskApp({super.key});

  @override
  State<AttendanceKioskApp> createState() => _AttendanceKioskAppState();
}

class _AttendanceKioskAppState extends State<AttendanceKioskApp>
    with WidgetsBindingObserver {
  Timer? _enforceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startEnforceTimer();
  }

  @override
  void dispose() {
    _enforceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRelock();
      _startEnforceTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 백그라운드면 polling 불필요 (resume 시 다시 시작)
      _enforceTimer?.cancel();
    }
  }

  /// 사용자가 시스템 pin dialog 에서 No thanks 를 눌러 lock 이 안 걸린 채
  /// 앱이 떠 있는 상태가 되면, 주기적으로 startLockTask 재호출하여
  /// 다이얼로그를 다시 띄운다 → 사용자가 OK 를 누를 때까지 강제.
  void _startEnforceTimer() {
    _enforceTimer?.cancel();
    _enforceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _maybeRelock(),
    );
  }

  Future<void> _maybeRelock() async {
    // 영속된 만료시각이 있다면 우선 평가 (만료 도래시 isEnabled 가 true 로 승격)
    await KioskIntent.armTimerIfPending();
    if (!await shouldLockKiosk()) return;
    if (await KioskLock.isLocked()) return;
    await KioskLock.start();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => FlavorBadgeOverlay(
        child: KioskEscapeWrapper(child: child ?? const SizedBox.shrink()),
      ),
      home: const AttendanceShellScreen(),
    );
  }
}
