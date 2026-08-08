/// App version gate — sideload APK 환경에서 강제/권장 업데이트 처리.
///
/// 동작:
///   1. 등록된 device token 으로 GET /attendance/app-version 호출 +
///      응답 헤더 (X-App-Latest-Version 등) piggyback 수신
///   2. current < min_version → 전체화면 blocker (Update 버튼만)
///   3. current < latest_version → 설정 화면에서 확인/설치
///   4. Update 탭 → 확인 모달 → appUpdateProvider 가 전역으로 다운로드 진행
///      (화면을 벗어나도 계속) → ready 에서 설치 버튼
///
/// min_version 이 null 이거나 current >= min → 통과.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:htm_core/htm_core.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_update_provider.dart';
import '../services/attendance_device_service.dart';
import '../widgets/app_update_banner.dart';

class AppVersionStatus {
  final String current;
  final String? minVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;

  const AppVersionStatus({
    required this.current,
    this.minVersion,
    this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
  });

  bool get blocking =>
      minVersion != null && _semverLess(current, minVersion!);

  bool get hasUpdate =>
      latestVersion != null && _semverLess(current, latestVersion!);

  /// 다운로드 대상 버전 라벨 — 파일명/확인 모달에 쓴다.
  /// latest 가 없으면 min 으로라도 특정한다 (blocker 는 min 만 있을 수 있음).
  String get updateTargetVersion => latestVersion ?? minVersion ?? 'latest';
}

/// "MAJOR.MINOR.PATCH" 또는 "MAJOR.MINOR.PATCH+BUILD" 를 비교한다.
/// semver 가 같으면 build number 까지 비교 — 1.0.7+25 < 1.0.7+26 → true.
/// 서버가 build number 없이 등록한 경우 (예: "1.0.8") 클라이언트의 build number 는 무시되어
/// 1.0.7+25 < 1.0.8 → true (semver 만으로 결정).
bool _semverLess(String a, String b) {
  final aParts = a.split('+');
  final bParts = b.split('+');
  final pa = aParts[0].split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = bParts[0].split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < n; i++) {
    final av = i < pa.length ? pa[i] : 0;
    final bv = i < pb.length ? pb[i] : 0;
    if (av < bv) return true;
    if (av > bv) return false;
  }
  // semver 동일 — 양쪽 다 build number 있을 때만 비교. 한 쪽만 있으면 비교 무시.
  if (aParts.length < 2 || bParts.length < 2) return false;
  final aBuild = int.tryParse(aParts[1]) ?? 0;
  final bBuild = int.tryParse(bParts[1]) ?? 0;
  return aBuild < bBuild;
}

/// PackageInfo 의 semver + buildNumber 를 "1.0.7+25" 형식으로 합쳐 반환.
/// buildNumber 가 비어 있으면 semver 만 반환.
String currentVersionString(PackageInfo pkg) {
  final b = pkg.buildNumber;
  return b.isEmpty ? pkg.version : '${pkg.version}+$b';
}

Future<AppVersionStatus?> fetchAppVersionStatus(
  AttendanceDeviceService service,
) async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final data = await service.getAppVersion();
    return AppVersionStatus(
      current: currentVersionString(pkg),
      minVersion: data['min_version'] as String?,
      latestVersion: data['latest_version'] as String?,
      downloadUrl: data['download_url'] as String?,
      releaseNotes: data['release_notes'] as String?,
    );
  } catch (_) {
    // 네트워크 실패 / 미인증 → enforcement 적용 안 함
    return null;
  }
}

/// 다운로드 시작 전 확인 모달 → 승인 시 전역 notifier 로 다운로드 시작.
/// 설정 화면과 blocker 화면이 공유한다 (이슈 1-1 — 시작 전 확인 일관 적용).
Future<void> confirmAndStartUpdateDownload(
  BuildContext context,
  WidgetRef ref, {
  required AppVersionStatus status,
}) async {
  final t = AppL10n.of(context);
  final url = status.downloadUrl;
  if (url == null || url.isEmpty) {
    await AppModal.show(
      context,
      title: t.attUpdateUnavailableTitle,
      message: t.attUpdateUnavailableMessage,
      type: ModalType.info,
    );
    return;
  }
  final version = status.updateTargetVersion;
  final confirmed = await AppModal.show(
    context,
    title: t.attUpdateConfirmTitle,
    message: t.attUpdateConfirmMessage(version),
    type: ModalType.confirm,
    confirmText: t.attUpdateConfirmOk,
  );
  if (confirmed != true) return;
  // 여기서부터는 BuildContext 무관 — notifier 가 화면 수명 밖에서 진행한다.
  await ref.read(appUpdateProvider.notifier).startDownload(url, version);
}

class UpdateBlockerScreen extends ConsumerWidget {
  final AppVersionStatus status;
  const UpdateBlockerScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final update = ref.watch(appUpdateProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.system_update,
                    size: 80,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t.attUpdateRequiredTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.attUpdateRequiredMessage(
                      status.current,
                      status.minVersion ?? '?',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (status.releaseNotes != null &&
                      status.releaseNotes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        status.releaseNotes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // 전역 배너와 중복 표시될 수 있지만 이 화면에선 화면 내 표시가 우선.
                  _buildAction(context, ref, t, update),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 하단 액션 영역 — 전역 업데이트 상태(phase)에 따라 전환.
  Widget _buildAction(
    BuildContext context,
    WidgetRef ref,
    AppL10n t,
    AppUpdateState update,
  ) {
    final notifier = ref.read(appUpdateProvider.notifier);
    switch (update.phase) {
      case AppUpdatePhase.downloading:
        final p = update.progress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: p,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              p == null
                  ? t.attUpdateDownloading
                  : '${(p * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        );
      case AppUpdatePhase.installing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              t.attUpdateLaunchingInstaller,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        );
      case AppUpdatePhase.ready:
        return FilledButton.icon(
          onPressed: notifier.install,
          icon: const Icon(Icons.install_mobile_rounded),
          label: Text(t.attUpdateInstallNow),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      case AppUpdatePhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appUpdateErrorMessage(t, update.errorKind),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: notifier.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.actionRetry),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        );
      case AppUpdatePhase.idle:
        return FilledButton.icon(
          onPressed: () =>
              confirmAndStartUpdateDownload(context, ref, status: status),
          icon: const Icon(Icons.download),
          label: Text(
            t.attUpdateDownloadButton(status.latestVersion ?? '?'),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
    }
  }
}
