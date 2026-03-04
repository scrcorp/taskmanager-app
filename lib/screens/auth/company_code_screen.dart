/// 회사 코드 입력 화면
///
/// 직원이 소속 회사의 company_code를 입력하는 첫 번째 인증 단계.
/// 입력한 코드를 TokenStorage에 저장한 후 회원가입 화면으로 이동.
/// 이미 계정이 있으면 로그인 화면으로 이동 가능.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../utils/token_storage.dart';

/// 회사 코드 입력 화면 위젯
class CompanyCodeScreen extends StatefulWidget {
  const CompanyCodeScreen({super.key});

  @override
  State<CompanyCodeScreen> createState() => _CompanyCodeScreenState();
}

class _CompanyCodeScreenState extends State<CompanyCodeScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 회사 코드 저장 후 회원가입 화면으로 이동
  Future<void> _next() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    await TokenStorage.setCompanyCode(code);
    if (mounted) context.go('/register?company_code=$code');
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
              Icon(Icons.business, size: 48, color: AppColors.accent),
              const SizedBox(height: 16),
              Text('Enter Company Code', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 8),
              Text('Ask your manager for the company code', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _next(),
                decoration: const InputDecoration(
                  hintText: 'Company Code',
                  prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text('Login', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
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
