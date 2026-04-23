/// `/attendance-temp` 진입 shell
///
/// Device 상태에 따라 적절한 화면으로 라우팅:
/// - needsRegister → AttendanceAccessCodeScreen
/// - needsStore    → AttendanceStoreSelectScreen
/// - ready         → AttendanceMainScreen
/// - loading/init  → 로딩 스피너
///
/// 기존 auth guard(JWT) 영향을 받지 않는 독립 shell.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_device_provider.dart';
import 'attendance_access_code_screen.dart';
import 'attendance_main_screen.dart';
import 'attendance_store_select_screen.dart';

/// Device 상태 기반 shell
class AttendanceShellScreen extends ConsumerStatefulWidget {
  const AttendanceShellScreen({super.key});

  @override
  ConsumerState<AttendanceShellScreen> createState() => _AttendanceShellScreenState();
}

class _AttendanceShellScreenState extends ConsumerState<AttendanceShellScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임 후 상태 체크 (build 사이클과 겹치지 않도록)
    Future.microtask(() => ref.read(attendanceDeviceProvider.notifier).checkStatus());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceDeviceProvider);

    Widget child;
    switch (state.status) {
      case AttendanceDeviceStatus.initial:
      case AttendanceDeviceStatus.loading:
        child = const _LoadingView();
        break;
      case AttendanceDeviceStatus.needsRegister:
        child = const AttendanceAccessCodeScreen();
        break;
      case AttendanceDeviceStatus.needsStore:
        child = const AttendanceStoreSelectScreen();
        break;
      case AttendanceDeviceStatus.ready:
        child = const AttendanceMainScreen();
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: child),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}
