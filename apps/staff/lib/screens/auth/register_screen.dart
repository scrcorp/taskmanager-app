/// 회원가입 화면 — 5단계 스텝 프로세스
///
/// Step 1: 이용약관 동의 (필수 2개 + 선택 1개)
/// Step 2: 매장 선택 (다중 선택, 최소 1개 필수)
/// Step 3: 개인정보 입력 (이름, 사용자명 중복 확인, 비밀번호)
/// Step 4: 이메일 입력 + 인증코드 발송/검증
/// Step 5: 가입 완료 및 서비스 시작
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/language_switcher.dart';

/// 회원가입 화면 위젯 — IndexedStack으로 5단계를 전환
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;

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
    final t = AppL10n.of(context);
    if (!_term1 || !_term2) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerTermsRequired,
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
    final t = AppL10n.of(context);
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
          _storesError = _parseApiError(e, t.registerStoresLoadFailed);
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
    final t = AppL10n.of(context);
    if (_selectedStoreIds.isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerSelectStoreRequired,
        type: ModalType.warning,
      );
      return;
    }
    _nextStep();
  }

  // Step 3: Info validation → move to email step
  Future<void> _validateStep3() async {
    final t = AppL10n.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerEnterName,
        type: ModalType.warning,
      );
      return;
    }
    if (_idCtrl.text.trim().isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerEnterUsername,
        type: ModalType.warning,
      );
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerEnterPassword,
        type: ModalType.warning,
      );
      return;
    }
    if (_confirmPwCtrl.text != _pwCtrl.text) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.resetPasswordsMismatchMessage,
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
    final t = AppL10n.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerEnterValidEmail,
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
          title: t.emailVerifyCodeSentTitle,
          message: t.emailVerifyCodeSentMessage,
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        final msg = _parseApiError(e, t.registerCodeSendFailed);
        if (e is DioException && e.response?.statusCode == 409) {
          setState(() { _emailError = msg; });
        } else {
          await AppModal.show(
            context,
            title: t.emailVerifyCodeSendErrorTitle,
            message: msg,
            type: ModalType.error,
          );
        }
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
          title: t.registerEmailVerifiedTitle,
          message: t.registerEmailVerifiedMessage,
          type: ModalType.info,
        );
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

  /// Email verified → register → complete
  Future<void> _submitRegistration() async {
    final t = AppL10n.of(context);
    if (!_emailVerified) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.registerVerifyEmailFirst,
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
      final error = ref.read(authProvider).error ?? t.registerFailedDefault;
      AppModal.show(
        context,
        title: t.registerFailedTitle,
        message: error,
        type: ModalType.error,
      );
    }
  }

  /// 서버 에러 응답에서 사용자 친화적 메시지 추출
  String _parseApiError(Object e, String fallback) {
    final t = AppL10n.of(context);
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
        return t.errorServerLater;
      }
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

  // Step 5: 이미 회원가입 완료 상태 → 홈으로 이동
  void _goHome() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
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
                      t.actionRegister,
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
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: LanguageSwitcher(),
                    ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepProgressBar(
                currentStep: _currentStep,
                labels: [
                  t.registerStepTerms,
                  t.registerStepStore,
                  t.registerStepInfo,
                  t.registerStepEmail,
                  t.registerStepDone,
                ],
              ),
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
    final t = AppL10n.of(context);
    final allAgreed = _term1 && _term2 && _term3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.registerTermsHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(t.registerTermsSubheading, style: Theme.of(context).textTheme.bodyMedium),
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
                    child: Text(
                      t.registerTermsBody,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _TermCheckbox(
                    label: t.registerAgreeAll,
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
                    label: t.registerAgreeTos,
                    value: _term1,
                    onChanged: (v) => setState(() => _term1 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: t.registerAgreePrivacy,
                    value: _term2,
                    onChanged: (v) => setState(() => _term2 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: t.registerAgreeMarketing,
                    value: _term3,
                    onChanged: (v) => setState(() => _term3 = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BottomButton(
            label: t.actionNext,
            onPressed: (_term1 && _term2) ? _validateStep1 : null,
          ),
        ],
      ),
    );
  }

  // Step 2: Store Selection
  Widget _buildStep2() {
    final t = AppL10n.of(context);
    final filtered = _filteredStores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.registerStoresHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            t.registerStoresSubheading,
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
                t.registerStoresSelectedCount(_selectedStoreIds.length),
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
              hintText: t.registerStoresSearchHint,
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
                            TextButton(onPressed: _loadStores, child: Text(t.actionRetry)),
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
                                      ? t.registerStoresNoSearchResult(_storeSearchCtrl.text)
                                      : t.registerStoresEmpty,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
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
            label: t.actionContinue,
            onPressed: _selectedStoreIds.isNotEmpty ? _validateStep2 : null,
          ),
        ],
      ),
    );
  }

  // Step 3: Info Form
  Widget _buildStep3() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.registerInfoHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(t.registerInfoSubheading, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormLabel(t.fieldFullName),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(hintText: t.hintFullName),
                  ),
                  const SizedBox(height: 20),
                  _FormLabel(t.fieldUsername),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: t.hintChooseUsername),
                  ),
                  const SizedBox(height: 20),
                  _FormLabel(t.fieldPassword),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: t.hintEnterPassword),
                  ),
                  const SizedBox(height: 20),
                  _FormLabel(t.fieldConfirmPassword),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPwCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _validateStep3(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: t.hintReenterPassword,
                      errorText: _confirmPwCtrl.text.isNotEmpty && _confirmPwCtrl.text != _pwCtrl.text
                          ? t.passwordsMismatchInline
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FormLabel(t.fieldPreferredLanguage),
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
          _BottomButton(label: t.actionContinue, onPressed: _validateStep3),
        ],
      ),
    );
  }

  // Step 4: Email Verification (moved from original Step 2)
  Widget _buildStep4() {
    final t = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.emailVerifyHeading, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(t.registerEmailSubheading, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _FormLabel(t.fieldEmail),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _emailCtrl,
            hint: t.hintEmailExample,
            buttonLabel: _codeSent ? t.actionResend : t.actionSendCode,
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
                    t.emailVerifyChangeEmail,
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
          _FormLabel(t.fieldVerificationCode),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _codeCtrl,
            hint: t.hint6DigitCode,
            buttonLabel: t.actionVerify,
            onButtonTap: _codeSent && !_emailVerified ? _verifyCode : null,
            isDone: _emailVerified,
            enabled: _codeSent && !_emailVerified,
          ),
          if (_codeSent && !_emailVerified && _remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t.emailVerifyTimerRemaining(_timerText),
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
                child: Text(
                  t.registerEmailVerifiedBadge,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ),
            ),
          if (_codeSent && !_emailVerified) ...[
            const SizedBox(height: 12),
            Text(
              t.registerCodeExpiresHint,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const Spacer(),
          _BottomButton(
            label: t.actionRegister,
            onPressed: _emailVerified ? (_isLoading ? null : _submitRegistration) : null,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // Step 5: Completion
  Widget _buildStep5() {
    final t = AppL10n.of(context);
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
            t.registerWelcomeName(name),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            t.registerCompleteTitle,
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
            t.registerCompleteMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          _BottomButton(
            label: t.actionGetStarted,
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
  final List<String> labels;

  const _StepProgressBar({required this.currentStep, required this.labels});

  @override
  Widget build(BuildContext context) {
    final totalSteps = labels.length;
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
              labels[i],
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
  final TextInputType? keyboardType;
  final bool isDone;
  final bool enabled;

  const _FieldWithButton({
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    this.onButtonTap,
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
