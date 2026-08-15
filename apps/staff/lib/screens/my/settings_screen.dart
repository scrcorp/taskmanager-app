/// 설정 화면
///
/// 개인 설정 항목들을 한 곳에 모은 화면. MyPage 진입점에서 메뉴 수가 늘어나
/// 분리. admin /settings 와 같은 패턴.
///
/// 항목:
/// - Add to Home Screen (설치 안 된 웹에서만 노출)
/// - Alert Settings → /my/alert-settings
/// - Edit Username (dialog)
/// - Preferred Language (bottom sheet picker) — 즉시 LocaleNotifier 반영
/// - Change Password → /my/change-password
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/availability_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/pwa_install_service.dart';
import '../../services/push_service.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';
import '../../widgets/availability_strip.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _pwa = PwaInstallService();

  /// "Add to Home Screen" 행 노출 방식. hidden 이면 행 자체를 그리지 않는다.
  /// 이미 설치됐거나 네이티브 빌드면 hidden.
  PwaInstallMode _installMode = PwaInstallMode.hidden;

  /// 푸시 상태 — 브라우저 권한 + 살아있는 구독을 대조해서 얻는다.
  /// unsupported 면 관련 행을 아예 그리지 않는다.
  PushState _pushState = PushState.unsupported;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _installMode = _pwa.mode;
    Future.microtask(_refreshPushState);
  }

  Future<void> _refreshPushState() async {
    final state = await ref.read(pushServiceProvider).reconcile();
    if (!mounted) return;
    setState(() => _pushState = state);
  }

  /// 푸시 토글. 켤 때는 권한 팝업이 뜰 수 있어 반드시 탭 핸들러에서 바로 호출한다.
  Future<void> _onTogglePush(bool turnOn) async {
    if (_pushBusy) return;
    final t = AppL10n.of(context);
    final service = ref.read(pushServiceProvider);
    setState(() => _pushBusy = true);
    try {
      if (turnOn) {
        final ok = await service.enable();
        if (!mounted) return;
        if (!ok) {
          // 거부/실패 — 실제 상태를 다시 읽어 blocked 인지 구분해 보여준다.
          ToastManager().error(context, t.pushEnableFailed);
        } else {
          ToastManager().success(context, t.pushEnabledToast);
        }
      } else {
        await service.disable();
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
    await _refreshPushState();
  }

  Future<void> _onSendTestPush() async {
    final t = AppL10n.of(context);
    try {
      final result = await ref.read(pushServiceProvider).sendTest();
      if (!mounted) return;
      // 요청이 성공한 것과 알림이 나간 것은 다르다. 등록된 기기가 없으면
      // 200 에 sent=0 이 오는데, 이걸 성공으로 표시하면 "보냈다는데 안 온다" 가 된다.
      if (result.delivered) {
        ToastManager().success(context, t.pushTestSent);
      } else if (!result.hasDevice) {
        ToastManager().error(context, t.pushTestNoDevice);
      } else {
        ToastManager().error(context, t.pushTestRejected);
      }
    } catch (_) {
      if (!mounted) return;
      ToastManager().error(context, t.pushTestFailed);
    }
  }

  /// "Add to Home Screen" 탭 처리.
  ///
  /// iOS 는 설치 API 가 없어 수동 안내 시트를, Chrome 계열은 네이티브 설치창을 띄운다.
  /// 반드시 탭 핸들러 안에서 바로 호출해야 한다 — 브라우저가 사용자 제스처 밖의
  /// 설치 프롬프트를 무시하기 때문.
  Future<void> _onAddToHomeScreen() async {
    if (_installMode == PwaInstallMode.iosManual) {
      await _showIosInstallSheet();
      return;
    }
    final t = AppL10n.of(context);
    final result = await _pwa.promptInstall();
    if (!mounted) return;
    if (result == PwaInstallResult.accepted) {
      ToastManager().success(context, t.addToHomeInstalled);
    } else if (result == PwaInstallResult.unavailable) {
      ToastManager().error(context, t.addToHomeUnavailable);
    }
    // dismissed(사용자 취소)는 조용히 넘어간다.
    // 프롬프트는 1회용이므로 소비된 뒤 상태를 다시 읽어 행을 갱신한다.
    setState(() => _installMode = _pwa.mode);
  }

  /// iOS 수동 설치 안내 시트 — 공유 → 홈 화면에 추가 3단계.
  Future<void> _showIosInstallSheet() async {
    final t = AppL10n.of(context);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(t.addToHomeTitle,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text(t.addToHomeIntro,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 16),
              _InstallStep(number: 1, text: t.addToHomeIosStep1, icon: Icons.ios_share),
              _InstallStep(number: 2, text: t.addToHomeIosStep2, icon: Icons.add_box_outlined),
              _InstallStep(number: 3, text: t.addToHomeIosStep3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.actionClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _languageLabel(String? code) {
    switch (code) {
      case 'es':
        return '🇪🇸 Español';
      case 'ko':
        return '🇰🇷 한국어';
      default:
        return '🇺🇸 English';
    }
  }

  /// "What's New" — 홈페이지 공개 changelog 를 브라우저(웹은 새 탭)로 연다.
  /// 앱 안에서 자체 목록을 렌더하지 않고 홈페이지 /changelog 를 단일 소스로 사용.
  Future<void> _openWhatsNew() async {
    final t = AppL10n.of(context);
    final uri = Uri.parse(AppConstants.changelogUrl);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ToastManager().error(context, t.changelogOpenError);
    }
  }

  Future<void> _showLanguagePicker() async {
    final t = AppL10n.of(context);
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t.fieldPreferredLanguage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            for (final entry in const [
              MapEntry('en', ('🇺🇸', 'English')),
              MapEntry('es', ('🇪🇸', 'Español')),
              MapEntry('ko', ('🇰🇷', '한국어')),
            ])
              ListTile(
                leading: Text(entry.value.$1, style: const TextStyle(fontSize: 22)),
                title: Text(entry.value.$2),
                trailing: user.preferredLanguage == entry.key
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == user.preferredLanguage) return;
    final success = await ref.read(authProvider.notifier).updateProfile({
      'preferred_language': selected,
    });
    if (!mounted) return;
    if (success) {
      // 즉시 화면 반영
      if (supportedLocales.any((l) => l.languageCode == selected)) {
        await ref.read(localeProvider.notifier).setLocale(Locale(selected));
      }
      if (!mounted) return;
      await AppModal.show(context,
          title: t.commonSavedTitle, message: t.settingsLanguageSaved, type: ModalType.success);
    } else {
      final error = ref.read(authProvider).error ?? t.settingsLanguageFailed;
      await AppModal.show(context,
          title: t.commonSaveFailedTitle, message: error, type: ModalType.error);
    }
  }

  Future<void> _showEditUsernameDialog() async {
    final t = AppL10n.of(context);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final controller = TextEditingController(text: user.username);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditUsernameDialog(controller: controller),
    );

    if (result != null && result.trim().isNotEmpty && result.trim() != user.username) {
      final success = await ref.read(authProvider.notifier).updateProfile({
        'username': result.trim(),
      });
      if (!mounted) return;
      if (success) {
        await AppModal.show(context,
            title: t.commonSavedTitle, message: t.settingsUsernameSaved, type: ModalType.success);
      } else {
        final error = ref.read(authProvider).error ?? t.settingsUsernameFailed;
        await AppModal.show(context,
            title: t.commonSaveFailedTitle, message: error, type: ModalType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: t.settingsHeader, isDetail: true, onBack: () => context.pop()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SCHEDULING ──
                  _SectionHeader(t.settingsSectionScheduling),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _AvailabilitySettingsRow(
                      onTap: () => context.push('/my/work-availability'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── GENERAL ──
                  _SectionHeader(t.settingsSectionGeneral),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // 설치 가능할 때만 노출 — 설치되면 사라진다.
                        if (_installMode != PwaInstallMode.hidden) ...[
                          _SettingsItem(
                            label: t.settingsAddToHomeScreen,
                            onTap: _onAddToHomeScreen,
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ],
                        _SettingsItem(
                          label: t.settingsAlertSettings,
                          onTap: () => context.push('/my/alert-settings'),
                        ),
                        // 푸시는 브라우저가 지원할 때만 노출. 차단 상태면 토글 대신
                        // 안내문을 보여준다 — 앱에서 권한 팝업을 되살릴 방법이 없다.
                        if (_pushState != PushState.unsupported) ...[
                          const Divider(height: 1, color: AppColors.border),
                          _PushSettingsRow(
                            state: _pushState,
                            busy: _pushBusy,
                            onChanged: _onTogglePush,
                          ),
                          // 테스트 발송은 진단 도구다. prod 에는 서버 엔드포인트
                          // 자체가 없으므로 행을 띄우면 눌러도 실패만 한다.
                          if (_pushState == PushState.enabled &&
                              !AppConstants.isProduction) ...[
                            const Divider(height: 1, color: AppColors.border),
                            _SettingsItem(
                              label: t.pushSendTest,
                              onTap: _onSendTestPush,
                            ),
                          ],
                        ],
                        const Divider(height: 1, color: AppColors.border),
                        _SettingsItem(
                          label: t.settingsEditUsername,
                          trailing: Text(
                            user?.username ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          onTap: _showEditUsernameDialog,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _SettingsItem(
                          label: t.fieldPreferredLanguage,
                          trailing: Text(
                            _languageLabel(user?.preferredLanguage),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          onTap: _showLanguagePicker,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _SettingsItem(
                          label: t.settingsChangePassword,
                          onTap: () => context.push('/my/change-password'),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _SettingsItem(
                          label: t.changelogTitle,
                          onTap: _openWhatsNew,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS 설치 안내 시트의 단계 한 줄 — 번호 배지 + 설명(+ 해당 단계의 아이콘).
class _InstallStep extends StatelessWidget {
  final int number;
  final String text;
  final IconData? icon;
  const _InstallStep({required this.number, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.accentBg, shape: BoxShape.circle),
            child: Text('$number',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.text, height: 1.4)),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

/// 푸시 알림 설정 행 — 토글 + (차단 시) 복구 안내.
///
/// 토글만 두면 "켜져 있는데 왜 안 와요" 문의가 생긴다. 브라우저가 차단한
/// 상태를 반드시 눈에 보이게 알려줘야 한다.
class _PushSettingsRow extends StatelessWidget {
  final PushState state;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _PushSettingsRow({
    required this.state,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final blocked = state == PushState.blocked;
    final on = state == PushState.enabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.settingsPushNotifications,
                    style: const TextStyle(fontSize: 15, color: AppColors.text)),
              ),
              if (busy)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: on,
                  // 차단 상태에서는 토글을 잠근다 — 눌러도 팝업이 안 뜨므로
                  // 조작 가능한 것처럼 보이면 안 된다.
                  onChanged: blocked ? null : onChanged,
                ),
            ],
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 40),
              child: Text(
                t.pushBlockedNotice,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.warning, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

/// 섹션 헤더 — 카드 위에 붙는 작은 대문자 muted 라벨 (mockup 규칙).
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// SCHEDULING 섹션의 "Work Availability" 행.
///
/// 설정 여부와 무관하게 미니 7칸 스트립으로 표시(미설정 = 전부 Off).
/// 미설정이면 제목 옆 "Not set" 배지로만 구분한다. 탭하면 /my/work-availability 로 이동.
class _AvailabilitySettingsRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _AvailabilitySettingsRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final async = ref.watch(myAvailabilityProvider);

    // 데이터 로드 완료 + 미설정일 때만 "Not set" 배지를 보여준다.
    final bool showNotSetBadge =
        async.maybeWhen(data: (a) => !a.isSet, orElse: () => false);

    // 제목 아래 본문: 설정됨(스트립) / 미설정(안내) / 로딩·실패(placeholder).
    final Widget body = async.when(
      loading: () => const AvailabilityStrip(days: null),
      error: (_, __) => AvailabilityStrip(
        days: null,
        placeholderText: t.workAvailabilityTapToView,
      ),
      // 설정/미설정 모두 스트립으로 표시 (미설정 = 전부 Off). 구분은 "Not set" 배지.
      data: (availability) => AvailabilityStrip(days: availability.days),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t.workAvailabilityTitle,
                        style: const TextStyle(fontSize: 15, color: AppColors.text),
                      ),
                      if (showNotSetBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.settingsAvailabilityNotSet,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  body,
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _SettingsItem({required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 15, color: AppColors.text)),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EditUsernameDialog extends StatefulWidget {
  final TextEditingController controller;
  const _EditUsernameDialog({required this.controller});

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late String _initial;

  @override
  void initState() {
    super.initState();
    _initial = widget.controller.text;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  bool get _canSave {
    final val = widget.controller.text.trim();
    return val.isNotEmpty && val != _initial;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.settingsEditUsername,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t.fieldUsername,
                hintText: t.settingsEnterNewUsername,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.actionCancel, style: const TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canSave ? () => Navigator.pop(context, widget.controller.text) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(t.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
