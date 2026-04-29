/// App version gate — sideload APK 환경에서 강제/권장 업데이트 처리.
///
/// 동작:
///   1. 등록된 device token 으로 GET /attendance/app-version 호출
///   2. current < min_version → 전체화면 blocker (Update 버튼만)
///   3. current < latest_version → 상단 권장 배너
///
/// min_version 이 null 이거나 current >= min → 통과.
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../services/attendance_device_service.dart';
import '../widgets/app_modal.dart';

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

bool _semverLess(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < n; i++) {
    final av = i < pa.length ? pa[i] : 0;
    final bv = i < pb.length ? pb[i] : 0;
    if (av < bv) return true;
    if (av > bv) return false;
  }
  return false;
}

Future<AppVersionStatus?> fetchAppVersionStatus(
  AttendanceDeviceService service,
) async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final data = await service.getAppVersion();
    return AppVersionStatus(
      current: pkg.version,
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

class UpdateBlockerScreen extends StatelessWidget {
  final AppVersionStatus status;
  const UpdateBlockerScreen({super.key, required this.status});

  Future<void> _onDownload(BuildContext context) async {
    final url = status.downloadUrl;
    if (url == null || url.isEmpty) {
      await AppModal.show(
        context,
        title: 'Update Unavailable',
        message: 'No download URL configured. Contact your administrator.',
        type: ModalType.info,
      );
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await AppModal.show(
        context,
        title: 'Cannot Open Download',
        message: 'Failed to launch the download URL.',
        type: ModalType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'App Update Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This device is running ${status.current} but ${status.minVersion} or higher is required to continue.',
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
                  FilledButton.icon(
                    onPressed: () => _onDownload(context),
                    icon: const Icon(Icons.download),
                    label: Text(
                      'Download Update (v${status.latestVersion ?? "?"})',
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

class UpdateAvailableBanner extends StatelessWidget {
  final AppVersionStatus status;
  final VoidCallback onDismiss;
  const UpdateAvailableBanner({
    super.key,
    required this.status,
    required this.onDismiss,
  });

  Future<void> _onDownload(BuildContext context) async {
    final url = status.downloadUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update available: v${status.latestVersion} (current v${status.current})',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _onDownload(context),
              child: const Text('Update'),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
