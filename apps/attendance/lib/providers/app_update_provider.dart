/// 앱 업데이트 다운로드/설치 전역 상태.
///
/// 다운로드 상태가 화면(State) 로컬에 살면 화면을 벗어나는 순간 진행률도
/// 완료 통지도 사라진다 (2026-08-07 이슈 1). 그래서 앱 수명의 StateNotifier
/// 로 승격했다 — 어느 화면에서 시작하든 계속 진행되고, 전역 배너
/// (AppUpdateOverlay) 가 어디서든 상태를 보여준다.
///
/// 원칙:
///   - BuildContext 는 절대 잡지 않는다. 확인 모달/표시는 UI 레이어 담당.
///   - 에러는 종류(errorKind)로만 노출 — raw 메시지는 UI 로 새지 않는다.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../utils/app_installer.dart';

/// 업데이트 흐름 단계.
enum AppUpdatePhase { idle, downloading, ready, installing, error }

/// 실패 원인 분류 — l10n 메시지(원인+다음 행동) 선택에 쓴다.
enum AppUpdateErrorKind { network, disk, installer, unknown }

class AppUpdateState {
  final AppUpdatePhase phase;

  /// downloading 중 0.0~1.0. content-length 헤더가 없으면 null (indeterminate).
  final double? progress;

  /// ready 이후 완성본 APK 경로.
  final String? apkPath;

  /// 진행/재시도 대상 버전 ("1.0.12+33" 형식).
  final String? targetVersion;

  /// 재시도용으로 저장해 두는 다운로드 URL.
  final String? downloadUrl;

  /// phase == error 일 때만 의미 있음.
  final AppUpdateErrorKind? errorKind;

  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.progress,
    this.apkPath,
    this.targetVersion,
    this.downloadUrl,
    this.errorKind,
  });

  AppUpdateState copyWith({
    AppUpdatePhase? phase,
    double? progress,
    String? apkPath,
    String? targetVersion,
    String? downloadUrl,
    AppUpdateErrorKind? errorKind,
    bool clearProgress = false,
    bool clearErrorKind = false,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      progress: clearProgress ? null : (progress ?? this.progress),
      apkPath: apkPath ?? this.apkPath,
      targetVersion: targetVersion ?? this.targetVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      errorKind: clearErrorKind ? null : (errorKind ?? this.errorKind),
    );
  }
}

/// 테스트 주입용 함수 시그니처 — 기본값은 AppInstaller 의 실제 구현.
typedef DownloadApkFn = Future<String> Function(
  String url, {
  required String version,
  DownloadProgress? onProgress,
});
typedef InstallApkFn = Future<void> Function(String apkPath);
typedef ExistingApkPathFn = Future<String?> Function(String version);

/// 앱 업데이트 전역 Provider (앱 수명 싱글톤)
final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  return AppUpdateNotifier();
});

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final DownloadApkFn _download;
  final InstallApkFn _install;
  final ExistingApkPathFn _existingApkPath;

  AppUpdateNotifier({
    DownloadApkFn? download,
    InstallApkFn? install,
    ExistingApkPathFn? existingApkPath,
  })  : _download = download ?? AppInstaller.downloadApk,
        _install = install ?? AppInstaller.installApk,
        _existingApkPath = existingApkPath ?? AppInstaller.existingApkPath,
        super(const AppUpdateState());

  /// [version] 대상 다운로드 시작. 완료되면 ready — 설치는 사용자가
  /// 배너/화면의 설치 버튼으로 이어간다.
  ///
  /// - 이미 진행 중(downloading/installing)이면 무시 — 중복 시작 방지.
  /// - 같은 버전의 완성본이 캐시에 있으면 재다운로드 없이 즉시 ready.
  Future<void> startDownload(String url, String version) async {
    if (state.phase == AppUpdatePhase.downloading ||
        state.phase == AppUpdatePhase.installing) {
      return;
    }
    state = AppUpdateState(
      phase: AppUpdatePhase.downloading,
      targetVersion: version,
      downloadUrl: url,
    );
    try {
      final cached = await _existingApkPath(version);
      if (cached != null) {
        if (!mounted) return;
        state = state.copyWith(
          phase: AppUpdatePhase.ready,
          apkPath: cached,
          progress: 1.0,
        );
        return;
      }
      final path = await _download(
        url,
        version: version,
        onProgress: (p) {
          // 화면이 아니라 notifier 가 진행률을 받는다 — dispose 될 State 없음.
          if (!mounted) return;
          if (state.phase == AppUpdatePhase.downloading) {
            state = state.copyWith(progress: p);
          }
        },
      );
      if (!mounted) return;
      state = state.copyWith(
        phase: AppUpdatePhase.ready,
        apkPath: path,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: AppUpdatePhase.error,
        errorKind: _classifyDownloadError(e),
        clearProgress: true,
      );
    }
  }

  /// ready 상태에서만 동작. 키오스크가 잠겨 있으면 임시 해제(기본 5분 후
  /// 자동 재잠금) 후 OS 설치 intent 를 발사한다.
  ///
  /// installing 은 intent 발사 동안만 유지되는 과도 상태다. OpenFilex.open 은
  /// 설치 완료가 아니라 intent 발사 시점에 반환하므로, 사용자가 OS 설치
  /// 다이얼로그에서 취소하고 앱으로 돌아올 수 있다 — installing 을 종착
  /// 상태로 두면 그 경우 복구 경로가 없어 배너/blocker 가 영구 고착된다.
  /// 발사 성공 후엔 ready 로 되돌린다 (apkPath 캐시 유지 → 재설치 즉시 가능).
  /// 실제 설치가 완료되면 프로세스가 교체되므로 이 ready 상태는 어차피
  /// 사용자에게 보이지 않고 소멸한다.
  Future<void> install() async {
    if (state.phase != AppUpdatePhase.ready) return;
    final apkPath = state.apkPath;
    if (apkPath == null) return;
    state = state.copyWith(phase: AppUpdatePhase.installing);
    try {
      // 키오스크 lock-task 중엔 OS 설치 관리자가 전면에 못 뜬다 → 잠깐 해제.
      if (await KioskLock.isLocked()) {
        await KioskIntent.disableTemporarily();
        await KioskLock.stop();
      }
      await _install(apkPath);
      // intent 발사 성공 — 제어는 OS PackageInstaller 로 넘어갔다.
      // 취소 후 복귀에 대비해 ready 로 복귀 (위 doc comment 참고).
      if (!mounted) return;
      state = state.copyWith(phase: AppUpdatePhase.ready);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: AppUpdatePhase.error,
        errorKind: AppUpdateErrorKind.installer,
      );
    }
  }

  /// error 상태에서 저장된 url/version 으로 재시도.
  /// (installer 실패였다면 완성본 캐시가 살아 있어 즉시 ready 로 돌아온다.)
  Future<void> retry() async {
    if (state.phase != AppUpdatePhase.error) return;
    final url = state.downloadUrl;
    final version = state.targetVersion;
    if (url == null || version == null) {
      state = const AppUpdateState();
      return;
    }
    state = const AppUpdateState();
    await startDownload(url, version);
  }

  /// error 배너의 닫기(X) — idle 로 복귀.
  void dismissError() {
    if (state.phase != AppUpdatePhase.error) return;
    state = const AppUpdateState();
  }

  AppUpdateErrorKind _classifyDownloadError(Object e) {
    if (e is DioException) {
      // Dio 가 디스크 쓰기 실패(FileSystemException 등)를 감싸 던지는 경우 원인 우선.
      if (e.error is IOException) return AppUpdateErrorKind.disk;
      return AppUpdateErrorKind.network;
    }
    // FileSystemException 은 IOException 을 구현한다.
    if (e is IOException) return AppUpdateErrorKind.disk;
    return AppUpdateErrorKind.unknown;
  }
}
