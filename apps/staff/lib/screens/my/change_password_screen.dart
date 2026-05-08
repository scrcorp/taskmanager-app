/// 비밀번호 변경 화면 (마이페이지에서 접근)
///
/// 현재 비밀번호 확인 + 새 비밀번호 설정.
/// 성공 시 새 토큰으로 현재 세션 유지 + Toast + /my로 이동.
/// API: POST /auth/change-password (JWT 인증 필요)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final t = AppL10n.of(context);
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.resetMissingFields,
        type: ModalType.warning,
      );
      return;
    }
    if (newPw != confirm) {
      await AppModal.show(
        context,
        title: t.resetPasswordsMismatchTitle,
        message: t.resetPasswordsMismatchMessage,
        type: ModalType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).changePassword(current, newPw);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await AppModal.show(
        context,
        title: t.changePasswordSuccessTitle,
        message: t.changePasswordSuccessMessage,
        type: ModalType.success,
      );
      if (!mounted) return;
      context.pop();
    } else {
      final error = ref.read(authProvider).error ?? t.changePasswordFailedDefault;
      await AppModal.show(
        context,
        title: t.changePasswordFailedTitle,
        message: error,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(t.changePasswordHeader),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.changePasswordHeading, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                t.changePasswordSubheading,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Text(t.fieldCurrentPassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: t.hintEnterCurrentPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(t.fieldNewPassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: t.hintEnterNewPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(t.fieldConfirmNewPassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [],
                onSubmitted: (_) => _changePassword(),
                decoration: InputDecoration(
                  hintText: t.hintReenterNewPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.changePasswordDevicesNote,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t.changePasswordHeader),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
