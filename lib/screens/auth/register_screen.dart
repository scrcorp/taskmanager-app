import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_modal.dart';

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

  // Step 2: Email verification
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _emailVerified = false;

  // Step 3: Info
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _idChecked = false;
  bool _pwConfirmed = false;

  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    _companyCode = uri.queryParameters['company_code'] ?? '';
  }

  @override
  void dispose() {
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
  void _validateStep1() {
    if (!_term1 || !_term2) {
      ToastManager().warning(context, 'Please agree to all required terms.');
      return;
    }
    _nextStep();
  }

  // Step 2: Email verification
  // TODO: Connect to server email verification API when available
  Future<void> _sendCode() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, 'Please enter your email.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      ToastManager().success(context, 'Verification code sent.');
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, 'Please enter the verification code.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _emailVerified = true;
        _isLoading = false;
      });
      ToastManager().success(context, 'Email verified successfully.');
    }
  }

  void _validateStep2() {
    if (!_emailVerified) {
      ToastManager().warning(context, 'Please complete email verification.');
      return;
    }
    _nextStep();
  }

  // Step 3: Info validation
  Future<void> _checkId() async {
    if (_idCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, 'Please enter a username.');
      return;
    }
    setState(() => _isLoading = true);
    // TODO: Connect to server username check API when available
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _idChecked = true;
        _isLoading = false;
      });
      ToastManager().success(context, 'Username is available.');
    }
  }

  void _confirmPassword() {
    if (_confirmPwCtrl.text.isEmpty) {
      ToastManager().warning(context, 'Please enter your password.');
      return;
    }
    if (_confirmPwCtrl.text != _pwCtrl.text) {
      ToastManager().warning(context, 'Passwords do not match.');
      return;
    }
    setState(() => _pwConfirmed = true);
    ToastManager().success(context, 'Password confirmed.');
  }

  void _validateStep3() {
    if (_nameCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, 'Please enter your name.');
      return;
    }
    if (!_idChecked) {
      ToastManager().warning(context, 'Please check username availability.');
      return;
    }
    if (_pwCtrl.text.length < 6) {
      ToastManager().warning(context, 'Password must be at least 6 characters.');
      return;
    }
    if (!_pwConfirmed) {
      ToastManager().warning(context, 'Please confirm your password.');
      return;
    }
    _nextStep();
  }

  // Step 4: actual register call
  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).register(
      username: _idCtrl.text.trim(),
      password: _pwCtrl.text,
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/home');
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
                  if (_currentStep < 3)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _currentStep == 0
                          ? () => context.go('/login')
                          : _prevStep,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  if (_currentStep < 3)
                    Text(
                      'Register',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (_currentStep == 3)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: _completeRegistration,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepProgressBar(currentStep: _currentStep, totalSteps: 4),
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

  // Step 2: Email Verification
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email Verification', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Verify your identity via email.', style: Theme.of(context).textTheme.bodyMedium),
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
          ),
          const SizedBox(height: 20),
          const _FormLabel('Verification Code'),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _codeCtrl,
            hint: '6-digit code',
            buttonLabel: 'Verify',
            onButtonTap: _codeSent && !_emailVerified ? _verifyCode : null,
            isDone: _emailVerified,
          ),
          const Spacer(),
          _BottomButton(
            label: 'Continue',
            onPressed: _emailVerified ? _validateStep2 : null,
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
                  _FieldWithButton(
                    controller: _idCtrl,
                    hint: 'Choose a username',
                    buttonLabel: 'Check',
                    onButtonTap: _idChecked ? null : _checkId,
                    isDone: _idChecked,
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'At least 6 characters'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  _FieldWithButton(
                    controller: _confirmPwCtrl,
                    hint: 'Re-enter your password',
                    buttonLabel: 'Confirm',
                    onButtonTap: _pwConfirmed ? null : _confirmPassword,
                    obscureText: true,
                    isDone: _pwConfirmed,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BottomButton(label: 'Next', onPressed: _validateStep3),
        ],
      ),
    );
  }

  // Step 4: Completion
  Widget _buildStep4() {
    final name = _nameCtrl.text.trim();
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
          const SizedBox(height: 32),
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
            onPressed: _isLoading ? null : _completeRegistration,
            isLoading: _isLoading,
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

  static const _labels = ['Terms', 'Verify', 'Info', 'Complete'];

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
                fontSize: 11,
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

  const _FieldWithButton({
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    this.onButtonTap,
    this.obscureText = false,
    this.keyboardType,
    this.isDone = false,
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
