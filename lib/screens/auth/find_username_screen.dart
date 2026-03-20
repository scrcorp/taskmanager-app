/// 아이디 찾기 화면
///
/// 3단계 흐름:
/// Step 1: 이메일 입력 → POST /auth/find-username → 마스킹 username 표시
/// Step 2: 마스킹 결과 확인 → 인증코드 발송 → 코드 입력 활성화
/// Step 3: 인증코드 검증 → full username 표시 + 로그인/비밀번호 재설정 버튼
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_manager.dart';

class FindUsernameScreen extends ConsumerStatefulWidget {
  const FindUsernameScreen({super.key});

  @override
  ConsumerState<FindUsernameScreen> createState() => _FindUsernameScreenState();
}

class _FindUsernameScreenState extends ConsumerState<FindUsernameScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  int _step = 1; // 1: 이메일, 2: 마스킹 결과 + 코드 입력, 3: full username
  String _maskedUsername = '';
  String _fullUsername = '';
  bool _codeSent = false;
  bool _isLoading = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _remainingSeconds = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) t.cancel();
      });
    });
  }

  String get _timerText {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _searchUsername() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ToastManager().warning(context, 'Please enter your email.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.findUsername(email);
      if (mounted) {
        setState(() {
          _maskedUsername = data['masked_username'] as String? ?? '';
          _step = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastManager().error(context, _parseApiError(e, 'No account found with this email.'));
      }
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.findUsernameSendCode(email);
      if (mounted) {
        final expiresIn = data['expires_in'] as int? ?? 300;
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startTimer(expiresIn);
        ToastManager().success(context, 'Verification code sent.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastManager().error(context, _parseApiError(e, 'Failed to send code.'));
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || code.length != 6) {
      ToastManager().warning(context, 'Please enter the 6-digit code.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.findUsernameVerifyCode(_emailCtrl.text.trim(), code);
      if (mounted) {
        _timer?.cancel();
        setState(() {
          _fullUsername = data['username'] as String? ?? '';
          _step = 3;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastManager().error(context, _parseApiError(e, 'Verification failed.'));
      }
    }
  }

  String _parseApiError(Object e, String fallback) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String) return detail;
      }
    }
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server not responding. Please try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'No internet connection.';
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: _step == 3
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () {
                  if (_step == 2) {
                    setState(() {
                      _step = 1;
                      _codeSent = false;
                      _codeCtrl.clear();
                      _timer?.cancel();
                      _remainingSeconds = 0;
                    });
                  } else {
                    context.go('/login');
                  }
                },
              ),
        title: const Text('Find Username'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: _step == 1
            ? _buildStep1()
            : _step == 2
                ? _buildStep2()
                : _buildStep3(),
      ),
    );
  }

  // ── Step 1: 이메일 입력 ──────────────────────────────────────────────────

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find Your Username', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Enter the email address associated with your account.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _searchUsername(),
            decoration: const InputDecoration(hintText: 'example@email.com'),
          ),
          const SizedBox(height: 16),
          Text(
            "We'll look up your account and show a masked version of your username for verification.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchUsername,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Search'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 마스킹 결과 + 코드 입력 ─────────────────────────────────────

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Is this your account?', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'We found an account with the email you provided.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // 마스킹 결과 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('Username', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  _maskedUsername,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'To see your full username, verify your email.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // 인증코드 입력 영역
          const Text('Verification Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  enabled: _codeSent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '6-digit code'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_codeSent && !_isLoading) ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBg,
                    foregroundColor: AppColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
          if (_codeSent && _remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '\u23F1 $_timerText remaining',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ),
          if (_codeSent)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text("Didn't receive the code?", style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendCode,
                    child: Text('Resend Code', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _step = 1;
                      _codeSent = false;
                      _codeCtrl.clear();
                      _timer?.cancel();
                      _remainingSeconds = 0;
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Try Different Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: _isLoading && !_codeSent
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_codeSent ? 'Resend Code' : 'Send Code'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Full Username 표시 ───────────────────────────────────────────

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(40)),
            child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text('Username Found', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your username has been verified.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Full username 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('Your Username', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  _fullUsername,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Use this username to log in to your account.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/reset-password'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    foregroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Reset Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
