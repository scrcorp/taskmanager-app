/// 회원가입 화면 — 5단계 스텝 프로세스
///
/// Step 1: 이용약관 동의 (필수 2개 + 선택 1개)
/// Step 2: 매장 선택 (다중 선택, 최소 1개 필수)
/// Step 3: 개인정보 입력 (이름, 사용자명 중복 확인, 비밀번호)
/// Step 4: 이메일 입력 + 인증코드 발송/검증
/// Step 5: 가입 완료 및 서비스 시작
///
/// URL 쿼리에서 company_code를 받아와 표시하며,
/// Step 4 이메일 인증 완료 후 authProvider.register()로 실제 가입 처리.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_modal.dart';

/// 회원가입 화면 위젯 — IndexedStack으로 5단계를 전환
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;
  String _companyCode = '';

  // Step 1: Terms
  bool _term1 = false;
  bool _term2 = false;
  bool _term3 = false;

  // Step 2: Store selection
  List<Map<String, dynamic>> _stores = [];
  final Set<String> _selectedStoreIds = {};
  final _storeSearchCtrl = TextEditingController();
  bool _storesLoading = false;
  String? _storesError;

  // Step 3: Info
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  String _preferredLanguage = 'en';

  // Step 4: Email verification
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _emailVerified = false;
  String? _verificationToken;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _emailError;

  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    _companyCode = uri.queryParameters['company_code'] ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _storeSearchCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep++);
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep--);
  }

  // Step 1 validation
  Future<void> _validateStep1() async {
    if (!_term1 || !_term2) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please agree to all required terms.',
        type: ModalType.warning,
      );
      return;
    }
    _nextStep();
    // Load stores after moving to Step 2
    if (_stores.isEmpty && !_storesLoading) {
      await _loadStores();
    }
  }

  // Step 2: Store loading — login/register와 동일하게 auth_service 내부에서 TokenStorage 사용
  Future<void> _loadStores() async {
    setState(() { _storesLoading = true; _storesError = null; });
    try {
      final authService = ref.read(authServiceProvider);
      final stores = await authService.getStores();
      if (mounted) {
        setState(() { _stores = stores; _storesLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storesLoading = false;
          _storesError = _parseApiError(e, 'Failed to load stores.');
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStores {
    final query = _storeSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _stores;
    return _stores.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final address = (s['address'] as String? ?? '').toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  Future<void> _validateStep2() async {
    if (_selectedStoreIds.isEmpty) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please select at least one store.',
        type: ModalType.warning,
      );
      return;
    }
    _nextStep();
  }

  // Step 3: Info validation → move to email step
  Future<void> _validateStep3() async {
    if (_nameCtrl.text.trim().isEmpty) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please enter your name.',
        type: ModalType.warning,
      );
      return;
    }
    if (_idCtrl.text.trim().isEmpty) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please enter a username.',
        type: ModalType.warning,
      );
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please enter a password.',
        type: ModalType.warning,
      );
      return;
    }
    if (_confirmPwCtrl.text != _pwCtrl.text) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Passwords do not match.',
        type: ModalType.warning,
      );
      return;
    }
    _nextStep();
  }

  // Step 4: Email verification
  static final _emailRegex = RegExp(r'^[\w\-.]+@[\w\-]+(\.[\w\-]+)+$');

  void _startTimer() {
    _remainingSeconds = 300; // 5 minutes
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
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please enter a valid email address.',
        type: ModalType.warning,
      );
      return;
    }
    setState(() { _isLoading = true; _emailError = null; });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendVerificationCode(email);
      if (mounted) {
        setState(() { _codeSent = true; _isLoading = false; });
        _startTimer();
        await AppModal.show(
          context,
          title: 'Code Sent',
          message: 'Verification code sent.',
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        final msg = _parseApiError(e, 'Failed to send code. Please try again.');
        if (e is DioException && e.response?.statusCode == 409) {
          setState(() { _emailError = msg; });
        } else {
          await AppModal.show(
            context,
            title: "Couldn't send code",
            message: msg,
            type: ModalType.error,
          );
        }
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || code.length != 6) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please enter the 6-digit code.',
        type: ModalType.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyEmailCode(
        _emailCtrl.text.trim(), code,
      );
      if (mounted) {
        setState(() {
          _emailVerified = true;
          _verificationToken = result['verification_token'] as String;
          _isLoading = false;
        });
        _timer?.cancel();
        AppModal.show(
          context,
          title: 'Email Verified',
          message: 'Your email has been verified successfully.',
          type: ModalType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppModal.show(
          context,
          title: 'Verification Failed',
          message: _parseApiError(e, 'Verification failed.'),
          type: ModalType.error,
        );
      }
    }
  }

  /// Email verified → register → complete
  Future<void> _submitRegistration() async {
    if (!_emailVerified) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please verify your email first.',
        type: ModalType.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).register(
      username: _idCtrl.text.trim(),
      password: _pwCtrl.text,
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      verificationToken: _verificationToken!,
      storeIds: _selectedStoreIds.toList(),
      preferredLanguage: _preferredLanguage,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      _nextStep();
    } else {
      final error = ref.read(authProvider).error ?? 'Registration failed';
      AppModal.show(
        context,
        title: 'Registration Failed',
        message: error,
        type: ModalType.error,
      );
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

  // Step 5: 이미 회원가입 완료 상태 → 홈으로 이동
  void _goHome() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  if (_currentStep < 4)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _currentStep == 0
                          ? () => context.go('/login')
                          : _prevStep,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  if (_currentStep < 4)
                    Text(
                      'Register',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (_currentStep == 4)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: _goHome,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepProgressBar(currentStep: _currentStep, totalSteps: 5),
            ),

            // Content
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Terms
  Widget _buildStep1() {
    final allAgreed = _term1 && _term2 && _term3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review the Terms', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Please agree to the terms to use the service.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Terms of Service\n\n'
                      'These terms govern your use of the TaskManager service. '
                      'Please read them carefully before using the service.\n\n'
                      'Article 1 (Purpose)\n'
                      'These terms define the rights, obligations, and responsibilities '
                      'between the company and its members regarding the use of the service.\n\n'
                      'Article 2 (Definitions)\n'
                      'The definitions of terms used in these terms are as follows.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _TermCheckbox(
                    label: 'Agree to all terms',
                    value: allAgreed,
                    isBold: true,
                    onChanged: (_) {
                      final newVal = !allAgreed;
                      setState(() {
                        _term1 = newVal;
                        _term2 = newVal;
                        _term3 = newVal;
                      });
                    },
                  ),
                  const Divider(height: 24),
                  _TermCheckbox(
                    label: 'I agree to the Terms of Service. (Required)',
                    value: _term1,
                    onChanged: (v) => setState(() => _term1 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: 'I agree to the Privacy Policy. (Required)',
                    value: _term2,
                    onChanged: (v) => setState(() => _term2 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: 'I agree to receive marketing information. (Optional)',
                    value: _term3,
                    onChanged: (v) => setState(() => _term3 = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BottomButton(
            label: 'Next',
            onPressed: (_term1 && _term2) ? _validateStep1 : null,
          ),
        ],
      ),
    );
  }

  // Step 2: Store Selection
  Widget _buildStep2() {
    final filtered = _filteredStores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Your Stores', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Choose the stores you work at.\nYou can select multiple stores.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_selectedStoreIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedStoreIds.length} store${_selectedStoreIds.length > 1 ? 's' : ''} selected',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Search field
          TextField(
            controller: _storeSearchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search stores...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Store list
          Expanded(
            child: _storesLoading
                ? const Center(child: CircularProgressIndicator())
                : _storesError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                            const SizedBox(height: 12),
                            Text(_storesError!, style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _loadStores, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.store_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _storeSearchCtrl.text.isNotEmpty
                                      ? 'No stores found for "${_storeSearchCtrl.text}".'
                                      : 'No stores available.\nPlease contact your manager.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final store = filtered[index];
                              final id = store['id'] as String;
                              final isSelected = _selectedStoreIds.contains(id);
                              return _StoreItem(
                                name: store['name'] as String? ?? '',
                                address: store['address'] as String?,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedStoreIds.remove(id);
                                    } else {
                                      _selectedStoreIds.add(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
          ),
          const SizedBox(height: 12),
          _BottomButton(
            label: 'Continue',
            onPressed: _selectedStoreIds.isNotEmpty ? _validateStep2 : null,
          ),
        ],
      ),
    );
  }

  // Step 3: Info Form
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us about yourself', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Enter your basic information to get started.', style: Theme.of(context).textTheme.bodyMedium),
          if (_companyCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Company: $_companyCode',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('Full Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'Enter your full name'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Username'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Choose a username'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Enter password'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPwCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _validateStep3(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Re-enter your password',
                      errorText: _confirmPwCtrl.text.isNotEmpty && _confirmPwCtrl.text != _pwCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Preferred Language'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _preferredLanguage,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                      DropdownMenuItem(value: 'ko', child: Text('한국어')),
                    ],
                    onChanged: (v) => setState(() => _preferredLanguage = v ?? 'en'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BottomButton(label: 'Continue', onPressed: _validateStep3),
        ],
      ),
    );
  }

  // Step 4: Email Verification (moved from original Step 2)
  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify Your Email', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text("We'll send a verification code to your email.", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          const _FormLabel('Email'),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _emailCtrl,
            hint: 'example@email.com',
            buttonLabel: _codeSent ? 'Resend' : 'Send Code',
            onButtonTap: _emailVerified ? null : _sendCode,
            keyboardType: TextInputType.emailAddress,
            isDone: _emailVerified,
            enabled: !_codeSent || _emailVerified ? true : false,
          ),
          if (_codeSent && !_emailVerified)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _codeSent = false;
                    _codeCtrl.clear();
                    _timer?.cancel();
                    _remainingSeconds = 0;
                    _emailError = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Change Email',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          if (_emailError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                _emailError!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFFF6B6B)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const _FormLabel('Verification Code'),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _codeCtrl,
            hint: '6-digit code',
            buttonLabel: 'Verify',
            onButtonTap: _codeSent && !_emailVerified ? _verifyCode : null,
            isDone: _emailVerified,
            enabled: _codeSent && !_emailVerified,
          ),
          if (_codeSent && !_emailVerified && _remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '⏱ $_timerText remaining',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ),
          if (_emailVerified)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓ Email verified',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ),
            ),
          if (_codeSent && !_emailVerified) ...[
            const SizedBox(height: 12),
            Text(
              'Code expires in 5 minutes after sending.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const Spacer(),
          _BottomButton(
            label: 'Register',
            onPressed: _emailVerified ? (_isLoading ? null : _submitRegistration) : null,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // Step 5: Completion
  Widget _buildStep5() {
    final name = _nameCtrl.text.trim();
    final selectedStoreNames = _stores
        .where((s) => _selectedStoreIds.contains(s['id'] as String))
        .map((s) => s['name'] as String? ?? '')
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            'Welcome, $name!',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Registration Complete',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 40),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(80),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.waving_hand_rounded, size: 72, color: AppColors.accent),
                Positioned(
                  top: 20,
                  right: 24,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 28,
                  left: 20,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (selectedStoreNames.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: selectedStoreNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Start using the service right away.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          _BottomButton(
            label: 'Get Started',
            onPressed: _goHome,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Private sub-widgets
// ═══════════════════════════════════════════════════════════════

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressBar({required this.currentStep, required this.totalSteps});

  static const _labels = ['Terms', 'Store', 'Info', 'Email', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (i) {
            final isActive = i <= currentStep;
            return Text(
              _labels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: i == currentStep ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.accent : AppColors.textMuted,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StoreItem extends StatelessWidget {
  final String name;
  final String? address;
  final bool isSelected;
  final VoidCallback onTap;

  const _StoreItem({
    required this.name,
    this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentBg : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (address != null && address!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address!,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
    );
  }
}

class _TermCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isBold;

  const _TermCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: value ? AppColors.accent : AppColors.border, width: 1.5),
            ),
            child: value ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldWithButton extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String buttonLabel;
  final VoidCallback? onButtonTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool isDone;
  final bool enabled;

  const _FieldWithButton({
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    this.onButtonTap,
    this.obscureText = false,
    this.keyboardType,
    this.isDone = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            enabled: enabled,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: onButtonTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? AppColors.success : AppColors.accentBg,
              foregroundColor: isDone ? AppColors.white : AppColors.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: isDone ? const Icon(Icons.check_rounded, size: 18) : Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _BottomButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}
