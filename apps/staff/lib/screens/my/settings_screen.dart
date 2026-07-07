/// 설정 화면
///
/// 개인 설정 항목들을 한 곳에 모은 화면. MyPage 진입점에서 메뉴 수가 늘어나
/// 분리. admin /settings 와 같은 패턴.
///
/// 항목:
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
import '../../providers/locale_provider.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _SettingsItem(
                          label: t.settingsAlertSettings,
                          onTap: () => context.push('/my/alert-settings'),
                        ),
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
