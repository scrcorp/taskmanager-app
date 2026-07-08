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
  String? _currentAppVersion;  // PackageInfo cache
  Timer? _versionPollTimer;
  AttendanceDeviceService? _watchedService;
  /// 401/네트워크 실패 → fetchAppVersionStatus 가 null 반환할 때, 매 build 마다
  /// 자동 재시도 폭주 방지용. 1시간 폴링 타이머가 다시 시도하도록 둔다.
  bool _versionCheckInFlight = false;
  bool _versionCheckTriedSinceTick = false;

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
      (_) {
        _versionCheckTriedSinceTick = false; // 새 tick — 한 번 더 시도 허용
        _refreshVersionStatus();
      },
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
    });
  }

  Future<void> _refreshVersionStatus() async {
    // device token 이 있어야 endpoint 호출 가능. 없으면 skip.
    final state = ref.read(attendanceDeviceProvider);
    if (state.device == null) return;
    // 이번 tick 안에서는 한 번만 시도 — 401 무한 폭주 방지.
    if (_versionCheckInFlight || _versionCheckTriedSinceTick) return;
    _versionCheckInFlight = true;
    try {
      final svc = ref.read(attendanceDeviceServiceProvider);
      final status = await fetchAppVersionStatus(svc);
      if (!mounted) return;
      setState(() => _versionStatus = status);
    } finally {
      _versionCheckInFlight = false;
      _versionCheckTriedSinceTick = true;
    }
  }

  @override
  void dispose() {
    _versionPollTimer?.cancel();
    _watchedService?.versionBroadcast.removeListener(_onVersionBroadcast);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // device 가 null → non-null 로 전이될 때 (등록/store 선택 직후) 버전 체크
    // 한 번 더 허용. 1시간 기다리지 않고 즉시 새로 시도.
    ref.listen(attendanceDeviceProvider, (prev, next) {
      final hadDevice = prev?.device != null;
      final hasDevice = next.device != null;
      if (!hadDevice && hasDevice) {
        _versionCheckTriedSinceTick = false;
      }
    });
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

    // optional 업데이트(min_version ≤ current < latest)는 상단 배너로 알리지 않는다
    // (상시 노출이 거슬림) → 설정 화면에서 확인/설치. 강제 업데이트(current < min_version)만
    // 위에서 전체화면 blocker 로 앱을 멈춘다.
    //
    // 배너 제거(d2a14e4) 때 Scaffold 래핑도 함께 사라져, Scaffold 를 자체적으로 두지 않는
    // 등록/스토어 선택 화면의 TextField 가 "No Material widget found" 로 크래시했다.
    // 여기서 Material 조상을 보장한다(메인 화면은 자체 Scaffold 라 transparency 로 무해).
    return Material(type: MaterialType.transparency, child: child);
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
