/// 이메일 인증 화면 — 로그인 후 email_verified=false인 사용자용
///
/// 기존 이메일이 있으면 pre-fill, 수정 가능.
/// 인증 완료 시 /home으로 이동. 뒤로가기는 로그아웃.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_manager.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _verified = false;
  bool _isLoading = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill email from user data
    final user = ref.read(authProvider).user;
    if (user?.email != null) {
      _emailCtrl.text = user!.email!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 300;
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

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ToastManager().warning(context, 'Please enter your email.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendVerificationCode(email, purpose: 'login_verify');
      if (mounted) {
        setState(() { _codeSent = true; _isLoading = false; });
        _startTimer();
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
      await authService.confirmEmail(_emailCtrl.text.trim(), code);
      if (mounted) {
        _timer?.cancel();
        // refreshUser()를 여기서 호출하면 router redirect가 즉시 /home으로 보냄
        // 성공 화면을 먼저 보여준 뒤, "Go to Home" 버튼에서 refreshUser() 호출
        setState(() => _verified = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastManager().error(context, _parseApiError(e, 'Verification failed.'));
      }
    }
  }

  /// 서버 에러 응답에서 사용자 친화적 메시지 추출
  String _parseApiError(Object e, String fallback) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is Map<String, dynamic>) {
          return (detail['message'] as String?) ?? fallback;
        }
      }
    }
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later.';
      }
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
    // 성공 화면
    if (_verified) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.success),
                ),
                const SizedBox(height: 28),
                Text(
                  'Email Verified!',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your email has been verified successfully.\nYou can now use all features.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).refreshUser();
                      if (mounted) context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Go to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Spacer(),
                  Text('Email Verification', style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    // Mail icon
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(Icons.mail_outline_rounded, size: 36, color: AppColors.accent),
                    ),
                    const SizedBox(height: 24),
                    Text('Verify Your Email', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'To continue using TaskManager,\nplease verify your email address.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailCtrl,
                            enabled: !_codeSent,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'example@email.com'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBg,
                              foregroundColor: AppColors.accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            child: Text(_codeSent ? 'Resend' : 'Send Code'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _codeSent
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _codeSent = false;
                                  _codeCtrl.clear();
                                  _timer?.cancel();
                                  _remainingSeconds = 0;
                                });
                              },
                              child: Text(
                                'Change Email',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.accent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            )
                          : Text(
                              'You can change your email address if needed.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                    ),

                    if (_codeSent) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Verification Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '6-digit code'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyCode,
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
                      if (_remainingSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '⏱ $_timerText remaining',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                            ),
                          ),
                        ),
                    ],

                    const Spacer(),

                    // Logout link
                    TextButton(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/login');
                      },
                      child: Text(
                        'Log out',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
