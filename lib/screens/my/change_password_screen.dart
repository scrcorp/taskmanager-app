/// 비밀번호 변경 화면 (마이페이지에서 접근)
///
/// 현재 비밀번호 확인 + 새 비밀번호 설정.
/// 성공 시 새 토큰으로 현재 세션 유지 + Toast + /my로 이동.
/// API: POST /auth/change-password (JWT 인증 필요)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_manager.dart';

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
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      ToastManager().warning(context, 'Please fill in all fields.');
      return;
    }
    if (newPw != confirm) {
      ToastManager().error(context, 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).changePassword(current, newPw);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ToastManager().success(context, 'Password changed successfully.');
      context.pop();
    } else {
      final error = ref.read(authProvider).error ?? 'Failed to change password.';
      ToastManager().error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Change Password'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Enter your current password and set a new one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              const Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Enter current password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [],
                onSubmitted: (_) => _changePassword(),
                decoration: InputDecoration(
                  hintText: 'Re-enter new password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'After changing your password, all other devices will be logged out.',
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
                      : const Text('Change Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
