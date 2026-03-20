/// 로그인 화면
///
/// 이메일/사용자명 + 비밀번호로 로그인.
/// 성공 시 /home으로, 실패 시 에러 모달 표시.
/// 하단에 회원가입 링크 제공.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_modal.dart';

/// 로그인 화면 위젯 (Riverpod ConsumerStateful)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  /// 비밀번호 표시/숨김 토글
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 로그인 실행 — authProvider를 통해 API 호출
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);
    final success = await ref.read(authProvider.notifier).login(email, password);
    if (mounted) setState(() => _loading = false);

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final error = ref.read(authProvider).error ?? 'Login failed';
      AppModal.show(
        context,
        title: 'Login Failed',
        message: error,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              // 앱 로고 + 타이틀
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '● ', style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w800)),
                  TextSpan(text: 'TaskManager', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.text)),
                ]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text('Staff App', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 48),
              // 이메일/사용자명 입력
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Email or Username',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 + 표시 토글
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // 로그인 버튼 (로딩 중 스피너 표시)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Log In'),
                ),
              ),
              const SizedBox(height: 20),
              // Find Username / Forgot Password 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/find-username'),
                    child: Text('Find Username', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('|', style: TextStyle(color: AppColors.border, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/reset-password'),
                    child: Text('Forgot Password?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text('Register', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
