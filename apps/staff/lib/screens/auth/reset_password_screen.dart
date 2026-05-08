/// 비밀번호 재설정 화면
///
/// 4단계 흐름:
/// Step 1: Username + Email 입력 → POST /auth/reset-password/send-code
/// Step 2: 인증코드 입력 → POST /auth/reset-password/verify-code → reset_token 저장
/// Step 3: 새 비밀번호 입력 → POST /auth/reset-password/confirm
/// Step 4: 성공 화면 — "Go to Login" 버튼
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/language_switcher.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  int _step = 1;
  String _resetToken = '';
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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

  Future<void> _sendCode() async {
    final t = AppL10n.of(context);
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (username.isEmpty || email.isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.resetMissingUsernameEmail,
        type: ModalType.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.resetPasswordSendCode(username, email);
      if (mounted) {
        final expiresIn = data['expires_in'] as int? ?? 300;
        setState(() {
          _step = 2;
          _isLoading = false;
        });
        _startTimer(expiresIn);
        await AppModal.show(
          context,
          title: t.emailVerifyCodeSentTitle,
          message: t.emailVerifyCodeSentMessage,
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppModal.show(
          context,
          title: t.findUsernameNotFoundTitle,
          message: _parseApiError(e, t.resetNoAccountDefault),
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _resendCode() async {
    final t = AppL10n.of(context);
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.resetPasswordSendCode(username, email);
      if (mounted) {
        final expiresIn = data['expires_in'] as int? ?? 300;
        setState(() { _isLoading = false; _codeCtrl.clear(); });
        _startTimer(expiresIn);
        await AppModal.show(
          context,
          title: t.resetCodeResentTitle,
          message: t.resetCodeResentMessage,
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppModal.show(
          context,
          title: t.resetCodeResendErrorTitle,
          message: _parseApiError(e, t.resetCodeResendErrorDefault),
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _verifyCode() async {
    final t = AppL10n.of(context);
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || code.length != 6) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.emailVerifyMissing6Digit,
        type: ModalType.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final data = await authService.resetPasswordVerifyCode(_emailCtrl.text.trim(), code);
      if (mounted) {
        _timer?.cancel();
        setState(() {
          _resetToken = data['reset_token'] as String? ?? '';
          _step = 3;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppModal.show(
          context,
          title: t.emailVerifyFailedTitle,
          message: _parseApiError(e, t.emailVerifyFailedDefault),
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _confirmReset() async {
    final t = AppL10n.of(context);
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.resetMissingFields,
        type: ModalType.warning,
      );
      return;
    }
    if (newPassword != confirmPassword) {
      await AppModal.show(
        context,
        title: t.resetPasswordsMismatchTitle,
        message: t.resetPasswordsMismatchMessage,
        type: ModalType.error,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPasswordConfirm(_resetToken, newPassword);
      if (mounted) {
        setState(() {
          _step = 4;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppModal.show(
          context,
          title: t.resetFailedTitle,
          message: _parseApiError(e, t.resetFailedDefault),
          type: ModalType.error,
        );
      }
    }
  }

  String _parseApiError(Object e, String fallback) {
    final t = AppL10n.of(context);
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
        return t.errorServerNotResponding;
      }
      if (e.type == DioExceptionType.connectionError) {
        return t.errorNoInternet;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _step == 4
          ? AppBar(
              backgroundColor: AppColors.white,
              automaticallyImplyLeading: false,
              title: Text(t.resetHeader),
              centerTitle: true,
              elevation: 0,
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(child: LanguageSwitcher()),
                ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.white,
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () {
                  if (_step == 2) {
                    setState(() {
                      _step = 1;
                      _codeCtrl.clear();
                      _timer?.cancel();
                      _remainingSeconds = 0;
                    });
                  } else if (_step == 3) {
                    setState(() {
                      _step = 2;
                      _newPasswordCtrl.clear();
                      _confirmPasswordCtrl.clear();
                    });
                  } else {
                    context.go('/login');
                  }
                },
              ),
              title: Text(t.resetHeader),
              centerTitle: true,
              elevation: 0,
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(child: LanguageSwitcher()),
                ),
              ],
            ),
      body: SafeArea(
        child: _step == 1
            ? _buildStep1()
            : _step == 2
                ? _buildStep2()
                : _step == 3
                    ? _buildStep3()
                    : _buildStep4(),
      ),
    );
  }

  // ── Step 1: Username + Email ──────────────────────────────────────────────

  Widget _buildStep1() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.resetHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            t.resetSubheading,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(t.fieldUsername, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(hintText: t.hintEnterUsername),
          ),
          const SizedBox(height: 20),
          Text(t.fieldEmail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(hintText: t.hintEmailExample),
          ),
          const SizedBox(height: 16),
          Text(
            t.resetCodeSentInfo,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendCode,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t.actionSendVerificationCode),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 인증코드 입력 ─────────────────────────────────────────────────

  Widget _buildStep2() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.resetEnterCodeHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            t.resetCodeSentTo(_emailCtrl.text.trim()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _step = 1;
                _codeCtrl.clear();
                _timer?.cancel();
                _remainingSeconds = 0;
              });
            },
            child: Text(
              t.resetWrongEmail,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(t.fieldVerificationCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t.hint6DigitCode),
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
                  child: Text(t.actionVerify),
                ),
              ),
            ],
          ),
          if (_remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t.emailVerifyTimerRemaining(_timerText),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Text(t.codeNotReceivedPrompt, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _resendCode,
                  child: Text(t.actionResendCode, style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_codeCtrl.text.isNotEmpty && !_isLoading) ? _verifyCode : null,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t.actionContinue),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: 새 비밀번호 입력 ──────────────────────────────────────────────

  Widget _buildStep3() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.resetSetNewHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            t.resetSetNewSubheading,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(t.fieldNewPassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _newPasswordCtrl,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: t.hintEnterNewPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(t.fieldConfirmPassword, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmReset(),
            decoration: InputDecoration(
              hintText: t.hintReenterNewPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmReset,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t.actionResetPassword),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: 성공 ─────────────────────────────────────────────────────────

  Widget _buildStep4() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(40)),
            child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text(t.resetSuccessTitle, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            t.resetSuccessMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            t.resetSuccessDevicesNote,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go('/login'),
              child: Text(t.actionGoToLogin),
            ),
          ),
        ],
      ),
    );
  }
}
