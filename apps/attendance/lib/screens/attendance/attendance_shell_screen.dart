/// `/attendance-temp` 진입 shell
///
/// Device 상태에 따라 적절한 화면으로 라우팅:
/// - needsRegister → AttendanceAccessCodeScreen
/// - needsStore    → AttendanceStoreSelectScreen
/// - ready         → AttendanceMainScreen
/// - loading/init  → 로딩 스피너
///
/// 기존 auth guard(JWT) 영향을 받지 않는 독립 shell.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String? _currentAppVersion;  // PackageInfo cache
  Timer? _versionPollTimer;
  AttendanceDeviceService? _watchedService;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 후 상태 체크 (build 사이클과 겹치지 않도록)
    Future.microtask(() async {
      // PackageInfo 한 번만 불러서 캐시 (semver+build → "1.0.7+25")
      final pkg = await PackageInfo.fromPlatform();
      if (mounted) _currentAppVersion = currentVersionString(pkg);
      await ref.read(attendanceDeviceProvider.notifier).checkStatus();
      _refreshVersionStatus();
      _attachVersionBroadcastListener();
    });
    // 1시간 폴백 폴링 — idle kiosk catch-up.
    // 응답 헤더 piggyback 이 주 메커니즘이라 보조용.
    _versionPollTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _refreshVersionStatus(),
    );
  }

  void _attachVersionBroadcastListener() {
    final svc = ref.read(attendanceDeviceServiceProvider);
    if (identical(_watchedService, svc)) return;
    _watchedService?.versionBroadcast.removeListener(_onVersionBroadcast);
    _watchedService = svc;
    svc.versionBroadcast.addListener(_onVersionBroadcast);
  }

  void _onVersionBroadcast() {
    if (!mounted) return;
    final b = _watchedService?.versionBroadcast.value;
    if (b == null) return;
    final current = _currentAppVersion;
    if (current == null) return;
    setState(() {
      _versionStatus = AppVersionStatus(
        current: current,
        minVersion: b.minVersion,
        latestVersion: b.latestVersion,
        downloadUrl: b.downloadUrl,
        releaseNotes: _versionStatus?.releaseNotes,  // 헤더엔 release notes 없음 — 직전 fetch 값 유지
      );
      // 새 latestVersion 이 떴으면 dismiss 리셋해서 배너 다시 표시
      if (b.latestVersion != null &&
          _versionStatus!.hasUpdate) {
        _bannerDismissed = false;
      }
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
  void dispose() {
    _versionPollTimer?.cancel();
    _watchedService?.versionBroadcast.removeListener(_onVersionBroadcast);
    super.dispose();
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
