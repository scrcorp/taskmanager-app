/// 태블릿 설정 화면
///
/// 상단: device_name / store_name 표시
/// 메뉴:
/// - Change Store: 매장 선택 화면 재방문
/// - Unregister this device: 서버 레코드 삭제 + 로컬 토큰 삭제
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_device_provider.dart';
import '../../widgets/app_modal.dart';
import 'attendance_access_code_screen.dart';

/// 기기 설정 화면
class AttendanceSettingsScreen extends ConsumerWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(attendanceDeviceProvider).device;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Device Settings'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Device info card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.tablet_mac_rounded,
                    label: 'Device',
                    value: device?.deviceName ?? '—',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'Store',
                    value: device?.storeName ?? 'Not assigned',
                  ),
                  if (device?.deviceId != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.fingerprint,
                      label: 'Device ID',
                      value: device!.deviceId,
                      monospace: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Menu ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _MenuItem(
                    label: 'Change Store',
                    icon: Icons.swap_horiz,
                    onTap: () async {
                      // 재등록 flow — 기존 token 해제 후 새 access code 입력
                      final confirmed = await AppModal.show(
                        context,
                        title: 'Change Store',
                        message:
                            'To switch this device to a different store, you will need a new access code. The current device registration will be revoked.',
                        type: ModalType.confirm,
                        confirmText: 'Continue',
                      );
                      if (confirmed != true) return;
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: AppColors.bg,
                            appBar: AppBar(
                              title: const Text('Change Store'),
                              leading: IconButton(
                                icon:
                                    const Icon(Icons.chevron_left, size: 28),
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                              ),
                            ),
                            body: const SafeArea(
                              child: AttendanceAccessCodeScreen(
                                mode: AccessCodeMode.reset,
                              ),
                            ),
                          ),
                        ),
                      );
                      // 재등록 성공 시 shell 이 needsStore 상태로 전환되어 있으므로
                      // settings 를 닫고 shell 이 store-select 을 보여주도록 함.
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    label: 'Unregister This Device',
                    icon: Icons.logout,
                    isDestructive: true,
                    onTap: () async {
                      final confirmed = await AppModal.show(
                        context,
                        title: 'Unregister Device',
                        message:
                            'This device will be removed from the organization. You will need a new access code to register again.',
                        type: ModalType.confirm,
                        confirmText: 'Unregister',
                      );
                      if (confirmed == true) {
                        await ref
                            .read(attendanceDeviceProvider.notifier)
                            .unregister();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontFamilyFallback: monospace ? const ['monospace'] : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onTap;
  const _MenuItem({
    required this.label,
    required this.icon,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: color),
              ),
            ),
            if (!isDestructive)
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
