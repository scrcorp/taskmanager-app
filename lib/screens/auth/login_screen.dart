import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/token_storage.dart';
import '../../widgets/app_modal.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _companyCode;

  @override
  void initState() {
    super.initState();
    _checkCompanyCode();
  }

  Future<void> _checkCompanyCode() async {
    final code = await TokenStorage.getCompanyCode();
    if (code == null || code.isEmpty) {
      if (mounted) context.go('/company-code');
      return;
    }
    if (mounted) setState(() => _companyCode = code);
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).error ?? 'Login failed';
        AppModal.show(
          context,
          title: 'Login Failed',
          message: error,
          type: ModalType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '● ', style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w800)),
                  TextSpan(text: 'TaskManager', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.text)),
                ]),
              ),
              const SizedBox(height: 4),
              Text('Staff App', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              if (_companyCode != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/company-code'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          _companyCode!,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded, size: 14, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              TextField(controller: _usernameCtrl, decoration: const InputDecoration(hintText: 'Username')),
              const SizedBox(height: 14),
              TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Log In'),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => context.go('/register'),
                  child: Text('Register', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
