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
import '../../services/attendance_device_service.dart';
import '../../utils/app_version_gate.dart';
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
  AppVersionStatus? _versionStatus;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 후 상태 체크 (build 사이클과 겹치지 않도록)
    Future.microtask(() async {
      await ref.read(attendanceDeviceProvider.notifier).checkStatus();
      _refreshVersionStatus();
    });
  }

  Future<void> _refreshVersionStatus() async {
    // device token 이 있어야 endpoint 호출 가능. 없으면 skip.
    final state = ref.read(attendanceDeviceProvider);
    if (state.device == null) return;
    final svc = ref.read(attendanceDeviceServiceProvider);
    final status = await fetchAppVersionStatus(svc);
    if (!mounted) return;
    setState(() => _versionStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceDeviceProvider);

    // 등록된 기기인데 강제 업데이트 필요 → 모든 화면을 가리는 blocker
    if (_versionStatus != null && _versionStatus!.blocking) {
      return UpdateBlockerScreen(status: _versionStatus!);
    }

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
        // store 선택 직전에도 버전 체크가 가능하면 호출
        if (_versionStatus == null) {
          Future.microtask(_refreshVersionStatus);
        }
        child = const AttendanceStoreSelectScreen();
        break;
      case AttendanceDeviceStatus.ready:
        if (_versionStatus == null) {
          Future.microtask(_refreshVersionStatus);
        }
        child = const AttendanceMainScreen();
        break;
    }

    final showBanner = _versionStatus != null &&
        !_versionStatus!.blocking &&
        _versionStatus!.hasUpdate &&
        !_bannerDismissed;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (showBanner)
              UpdateAvailableBanner(
                status: _versionStatus!,
                onDismiss: () => setState(() => _bannerDismissed = true),
              ),
            Expanded(child: child),
          ],
        ),
      ),
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
