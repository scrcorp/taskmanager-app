/// App version gate — sideload APK 환경에서 강제/권장 업데이트 처리.
///
/// 동작:
///   1. 등록된 device token 으로 GET /attendance/app-version 호출 +
///      응답 헤더 (X-App-Latest-Version 등) piggyback 수신
///   2. current < min_version → 전체화면 blocker (Update 버튼만)
///   3. current < latest_version → 상단 권장 배너
///   4. Update 탭 → in-app 다운로드 + PackageInstaller intent ([AppInstaller])
///
/// min_version 이 null 이거나 current >= min → 통과.
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:htm_core/htm_core.dart';
import '../l10n/app_localizations.dart';
import '../services/attendance_device_service.dart';
import 'app_installer.dart';

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

/// 다운로드 + 설치 작업의 외부 노출용 상태. UI 가 disabled/progress 결정에 사용.
class _InstallController {
  double? progress;  // null = idle, 0.0 ~ 1.0 = downloading, 1.0 = handing off to OS
  String? error;

  bool get isRunning => progress != null && error == null;
}

/// 업데이트 설치 흐름: 다운로드 → "설치할래?" 확인 → 키오스크 자동해제 → 설치.
///
/// 사장님 요청 흐름 그대로 — 다운로드가 끝나면 설치 여부를 물어보고, 승인하면
/// lock-task 를 잠깐 풀어(5분 뒤 자동 재잠금) OS 설치 관리자가 포그라운드로 뜰 수
/// 있게 한 뒤 설치 intent 를 발사한다. 키오스크가 켜져 있으면 설치 관리자가 가려져
/// "설치가 안 되는" 문제를 이 자동 해제가 방지한다.
///
/// [onProgress]: null=idle, 0.0~1.0=다운로드 중, 1.0=설치 관리자 호출 중.
/// 사용자가 확인을 취소하면 onProgress(null) 로 되돌리고 조용히 종료.
Future<void> runUpdateInstall(
  BuildContext context, {
  required String url,
  required void Function(double? progress) onProgress,
}) async {
  final t = AppL10n.of(context);
  onProgress(0.0);
  final apkPath = await AppInstaller.downloadApk(
    url,
    onProgress: (p) => onProgress(p),
  );

  // 다운로드 완료 → 설치 확인 (in-app 다이얼로그라 lock-task 여부와 무관하게 표시됨)
  if (!context.mounted) return;
  final confirmed = await AppModal.show(
    context,
    title: t.attUpdateReadyTitle,
    message: t.attUpdateReadyMessage,
    type: ModalType.confirm,
    confirmText: t.attUpdateInstallNow,
  );
  if (confirmed != true) {
    onProgress(null);
    return;
  }

  // 키오스크가 잠겨 있으면 OS 설치 관리자가 가려진다 → 잠깐 해제 (5분 뒤 자동 재잠금).
  if (await KioskLock.isLocked()) {
    await KioskIntent.disableTemporarily();
    await KioskLock.stop();
  }

  onProgress(1.0); // 설치 관리자 호출 중
  await AppInstaller.installApk(apkPath);
}

class UpdateBlockerScreen extends StatefulWidget {
  final AppVersionStatus status;
  const UpdateBlockerScreen({super.key, required this.status});

  @override
  State<UpdateBlockerScreen> createState() => _UpdateBlockerScreenState();
}

class _UpdateBlockerScreenState extends State<UpdateBlockerScreen> {
  final _ctrl = _InstallController();

  Future<void> _onDownload() async {
    final t = AppL10n.of(context);
    final url = widget.status.downloadUrl;
    if (url == null || url.isEmpty) {
      await AppModal.show(
        context,
        title: t.attUpdateUnavailableTitle,
        message: t.attUpdateUnavailableMessage,
        type: ModalType.info,
      );
      return;
    }
    try {
      await runUpdateInstall(
        context,
        url: url,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _ctrl.progress = p);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ctrl.progress = null;
        _ctrl.error = e.toString();
      });
      await AppModal.show(
        context,
        title: t.attUpdateCannotOpenTitle,
        message: '${t.attUpdateCannotOpenMessage}\n\n$e',
        type: ModalType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final progress = _ctrl.progress;
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
                      widget.status.current,
                      widget.status.minVersion ?? '?',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (widget.status.releaseNotes != null &&
                      widget.status.releaseNotes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.status.releaseNotes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (progress != null) ...[
                    LinearProgressIndicator(
                      value: progress >= 1.0 ? null : progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress >= 1.0
                          ? t.attUpdateLaunchingInstaller
                          : '${(progress * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _ctrl.isRunning ? null : _onDownload,
                      icon: const Icon(Icons.download),
                      label: Text(
                        t.attUpdateDownloadButton(
                          widget.status.latestVersion ?? '?',
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
