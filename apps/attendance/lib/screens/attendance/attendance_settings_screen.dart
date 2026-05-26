/// 태블릿 설정 화면
///
/// 상단: device_name / store_name 표시
/// 메뉴:
/// - Change Store: 매장 선택 화면 재방문
/// - Unregister this device: 서버 레코드 삭제 + 로컬 토큰 삭제
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/attendance_device_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/attendance_device_storage.dart';
import 'attendance_access_code_screen.dart';
import 'attendance_manage_pin_screen.dart';

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
    final t = AppL10n.of(context);
    if (next) {
      // OFF -> ON : 시스템이 "App is pinned" 다이얼로그를 띄우는데
      // 사용자가 "No thanks" 누르면 lock 이 안 걸려 desync 발생 → 사전 안내 + 검증 + 재시도
      final proceed = await AppModal.show(
        context,
        title: t.attSettingsKioskEnableTitle,
        message: t.attSettingsKioskEnableMessage,
        type: ModalType.confirm,
        confirmText: t.actionContinue,
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
          title: t.attSettingsKioskNotActiveTitle,
          message: t.attSettingsKioskNotActiveMessage,
          type: ModalType.confirm,
          confirmText: t.actionRetry,
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
        dialogTitle: t.attSettingsKioskDisableTitle,
        confirmLabel: t.attSettingsKioskDisableConfirm,
      );
      if (!ok) return;
      await KioskIntent.disableTemporarily();
      await KioskLock.stop();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      setState(() => _kioskOn = false);
      await AppModal.show(
        context,
        title: t.attSettingsKioskDisabledTitle,
        message: t.attSettingsKioskDisabledMessage,
        type: ModalType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final device = ref.watch(attendanceDeviceProvider).device;
    final currentLocale = ref.watch(localeProvider);
    final effectiveLanguage =
        currentLocale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(t.attSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 언어 변경은 메인 화면 헤더 우상단에서 빠르게 가능 (직원 셀프서비스).
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
                    label: t.attSettingsDeviceLabel,
                    value: device?.deviceName ?? '—',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: t.attSettingsStoreLabel,
                    value: device?.storeName ?? t.attSettingsStoreNotAssigned,
                  ),
                  if (device?.deviceId != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.fingerprint,
                      label: t.attSettingsDeviceIdLabel,
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
                    label: 'Manage Mode',
                    icon: Icons.admin_panel_settings_rounded,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceManagePinScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    label: t.attSettingsChangeStore,
                    icon: Icons.swap_horiz,
                    onTap: () async {
                      // 재등록 flow — 기존 token 해제 후 새 access code 입력
                      final confirmed = await AppModal.show(
                        context,
                        title: t.attSettingsChangeStore,
                        message: t.attSettingsChangeStoreConfirm,
                        type: ModalType.confirm,
                        confirmText: t.actionContinue,
                      );
                      if (confirmed != true) return;
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: AppColors.bg,
                            appBar: AppBar(
                              title: Text(t.attSettingsChangeStore),
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
                    label: t.attSettingsUnregister,
                    icon: Icons.logout,
                    isDestructive: true,
                    onTap: () async {
                      final confirmed = await AppModal.show(
                        context,
                        title: t.attSettingsUnregisterConfirmTitle,
                        message: t.attSettingsUnregisterConfirmMessage,
                        type: ModalType.confirm,
                        confirmText: t.actionContinue,
                      );
                      if (confirmed != true) return;
                      if (!context.mounted) return;
                      // 매니저 access code 재확인 — 직원 임의 unregister 방지
                      final ok = await _verifyAccessCode(
                        context,
                        dialogTitle: t.attSettingsUnregisterVerifyTitle,
                        confirmLabel: t.attSettingsUnregisterVerifyConfirm,
                      );
                      if (!ok) return;
                      if (!context.mounted) return;
                      await ref
                          .read(attendanceDeviceProvider.notifier)
                          .unregister();
                      if (context.mounted) Navigator.of(context).pop();
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

/// Language selector widget — Spanish-speaking employees rely on this kiosk.
/// Inline 패턴: 현재 국기+이름 표시, row tap → bottom sheet picker.
class _LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onChanged;
  const _LanguageSelector({
    required this.currentLanguage,
    required this.onChanged,
  });

  String get _currentDisplay {
    switch (currentLanguage) {
      case 'es':
        return '🇪🇸 Español';
      default:
        return '🇺🇸 English';
    }
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = AppL10n.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t.attSettingsLanguageLabel,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                ),
              ),
              for (final entry in const [
                MapEntry('en', ('🇺🇸', 'English')),
                MapEntry('es', ('🇪🇸', 'Español')),
              ])
                ListTile(
                  leading: Text(entry.value.$1,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(entry.value.$2),
                  trailing: currentLanguage == entry.key
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, entry.key),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != currentLanguage) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language,
                  color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.attSettingsLanguageLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              _currentDisplay,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textMuted),
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
  final t = AppL10n.of(context);
  if (saved == null || saved.isEmpty) {
    await AppModal.show(
      context,
      title: t.attSettingsAccessCodePromptTitle,
      message: t.attSettingsAccessCodePromptMessage,
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
          Text(t.attSettingsAccessCodeEnter),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: InputDecoration(
              hintText: t.attSettingsAccessCodeHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim().toUpperCase()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text(t.actionCancel),
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
      title: t.attSettingsAccessCodeIncorrectTitle,
      message: t.attSettingsAccessCodeIncorrectMessage,
      type: ModalType.info,
    );
    return false;
  }
  return true;
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
    final t = AppL10n.of(context);
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
                Text(
                  t.attSettingsKioskLockTitle,
                  style: const TextStyle(fontSize: 15, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? t.attSettingsKioskLockOn
                      : t.attSettingsKioskLockOff,
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
