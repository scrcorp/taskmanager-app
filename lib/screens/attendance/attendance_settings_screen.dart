/// 태블릿 설정 화면
///
/// 상단: device_name / store_name 표시
/// 메뉴:
/// - Change Store: 매장 선택 화면 재방문
/// - Unregister this device: 서버 레코드 삭제 + 로컬 토큰 삭제
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_device_provider.dart';
import '../../utils/attendance_device_storage.dart';
import '../../utils/kiosk_intent.dart';
import '../../utils/kiosk_lock.dart';
import '../../widgets/app_modal.dart';
import 'attendance_access_code_screen.dart';

/// 기기 설정 화면
class AttendanceSettingsScreen extends ConsumerStatefulWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  ConsumerState<AttendanceSettingsScreen> createState() =>
      _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState
    extends ConsumerState<AttendanceSettingsScreen> {
  bool _kioskOn = true;
  bool _kioskLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadKioskState();
    // escape 게스처/타이머 등 다른 경로에서 toggle 상태가 바뀌어도 즉시 반영
    KioskIntent.stateNotifier.addListener(_onIntentChanged);
  }

  @override
  void dispose() {
    KioskIntent.stateNotifier.removeListener(_onIntentChanged);
    super.dispose();
  }

  void _onIntentChanged() {
    if (!mounted) return;
    setState(() {
      _kioskOn = KioskIntent.stateNotifier.value;
      _kioskLoaded = true;
    });
  }

  Future<void> _loadKioskState() async {
    final on = await KioskIntent.isEnabled();
    if (!mounted) return;
    setState(() {
      _kioskOn = on;
      _kioskLoaded = true;
    });
  }

  Future<void> _onToggleKiosk(bool next) async {
    if (next) {
      // OFF -> ON : 시스템이 "App is pinned" 다이얼로그를 띄우는데
      // 사용자가 "No thanks" 누르면 lock 이 안 걸려 desync 발생 → 사전 안내 + 검증 + 재시도
      final proceed = await AppModal.show(
        context,
        title: 'Enable Kiosk Lock',
        message:
            'Android will show a system dialog asking to pin this app. You MUST tap "Got it" / "OK" to enable kiosk mode. Tapping "No thanks" will leave the device unlocked.',
        type: ModalType.confirm,
        confirmText: 'Continue',
      );
      if (proceed != true) return;
      while (true) {
        await KioskIntent.setEnabled(true);
        await KioskLock.start();
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        // 시스템 다이얼로그 응답 대기 (사용자가 직접 탭해야 함)
        await Future.delayed(const Duration(milliseconds: 1200));
        final locked = await KioskLock.isLocked();
        if (locked) {
          if (!mounted) return;
          setState(() => _kioskOn = true);
          return;
        }
        if (!mounted) return;
        final retry = await AppModal.show(
          context,
          title: 'Lock Not Active',
          message:
              'You declined the pinning prompt. Kiosk mode is required for this device. Tap Retry and confirm the system dialog.',
          type: ModalType.confirm,
          confirmText: 'Retry',
        );
        if (retry != true) {
          // intent 만 ON 으로 남으면 자동 재잠금 의도가 살아있어 부적절 → OFF 처리
          await KioskIntent.setEnabled(false);
          if (!mounted) return;
          setState(() => _kioskOn = false);
          return;
        }
      }
    } else {
      // ON -> OFF : access code 검증 + 5분 후 자동 재잠금
      final ok = await _verifyAccessCode(
        context,
        dialogTitle: 'Disable Kiosk Lock',
        confirmLabel: 'Unlock',
      );
      if (!ok) return;
      await KioskIntent.disableTemporarily();
      await KioskLock.stop();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      setState(() => _kioskOn = false);
      await AppModal.show(
        context,
        title: 'Kiosk Disabled',
        message:
            'Kiosk lock will re-enable automatically in 5 minutes. Toggle it back on at any time to re-lock immediately.',
        type: ModalType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _KioskToggleTile(
                    enabled: _kioskOn,
                    loaded: _kioskLoaded,
                    onChanged: _onToggleKiosk,
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

/// 저장된 access code 와 일치하는지 dialog 로 확인.
/// 일치하면 true, 그 외 (취소/불일치/저장값 없음) false.
Future<bool> _verifyAccessCode(
  BuildContext context, {
  required String dialogTitle,
  required String confirmLabel,
}) async {
  final saved = (await AttendanceDeviceStorage.getAccessCode())?.trim().toUpperCase();
  if (!context.mounted) return false;
  if (saved == null || saved.isEmpty) {
    await AppModal.show(
      context,
      title: 'Cannot Continue',
      message:
          'No access code on file. Re-register this device to enable this action.',
      type: ModalType.info,
    );
    return false;
  }
  final controller = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the device access code.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: const InputDecoration(
              hintText: 'ABC123',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim().toUpperCase()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(ctx).pop(controller.text.trim().toUpperCase()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (entered == null) return false;
  if (entered != saved) {
    await AppModal.show(
      context,
      title: 'Incorrect Code',
      message: 'The access code did not match.',
      type: ModalType.info,
    );
    return false;
  }
  return true;
}

/// 키오스크 의도(intent)는 유지한 채 lock task 만 잠시 풀고 홈으로 보낸다.
/// 사용자가 앱으로 돌아오면 lifecycle observer 가 자동으로 재잠금.
Future<void> _minimizeToHome(BuildContext context) async {
  final ok = await _verifyAccessCode(
    context,
    dialogTitle: 'Minimize to Home',
    confirmLabel: 'Go Home',
  );
  if (!ok) return;
  // Lock Task 가 켜진 상태에선 moveTaskToBack 이 차단되므로 먼저 stop.
  // intent 는 그대로 true 라서 resume 시 다시 잠긴다.
  await KioskLock.stop();
  await KioskLock.moveToBack();
}

/// 키오스크 잠금을 의도적으로 해제 (관리자 점검/설치 작업용).
/// intent flag 를 false 로 내려 부팅/resume 자동잠금도 멈춘다.
Future<void> _exitKiosk(BuildContext context) async {
  final ok = await _verifyAccessCode(
    context,
    dialogTitle: 'Exit Kiosk Mode',
    confirmLabel: 'Unlock',
  );
  if (!ok) return;
  await KioskIntent.setEnabled(false);
  await KioskLock.stop();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  if (!context.mounted) return;
  await AppModal.show(
    context,
    title: 'Kiosk Unlocked',
    message:
        'You may now navigate away from the app. Re-register or reinstall to re-enable kiosk mode.',
    type: ModalType.info,
  );
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

class _KioskToggleTile extends StatelessWidget {
  final bool enabled;
  final bool loaded;
  final ValueChanged<bool> onChanged;
  const _KioskToggleTile({
    required this.enabled,
    required this.loaded,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.lock : Icons.lock_open,
            size: 20,
            color: AppColors.text,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kiosk Lock',
                  style: TextStyle(fontSize: 15, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'App is locked. Disable to use device freely.'
                      : 'App is unlocked. Enable to restrict device.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: loaded ? onChanged : null,
          ),
        ],
      ),
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
