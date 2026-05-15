/// Clock-out 직후 팁 입력 화면 (매장 비치 태블릿).
///
/// Stage A: card_tips + cash_tips_kept 두 필드만. 동료 분배는 staff app 에서
/// 추가/수정 (이 화면에서는 단순화). "No tips today — Skip & Continue" 로
/// 건너뛸 수 있다.
///
/// 진입: AttendancePinScreen 이 clock-out 성공한 직후 pushReplacement.
/// 종료: Submit 또는 Skip 후 AttendanceSuccessScreen 으로 pushReplacement.
///
/// PIN 은 AttendancePinScreen 에서 검증되었지만 tip-entry API 가 server 측에서
/// 다시 검증한다 (같은 PIN 그대로 전달).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/attendance_device_service.dart';
import 'attendance_main_screen.dart';
import 'attendance_success_screen.dart';

class AttendanceTipEntryScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String pin;
  final int? workedMinutes;

  const AttendanceTipEntryScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.pin,
    this.workedMinutes,
  });

  @override
  ConsumerState<AttendanceTipEntryScreen> createState() =>
      _AttendanceTipEntryScreenState();
}

class _AttendanceTipEntryScreenState
    extends ConsumerState<AttendanceTipEntryScreen> {
  // 빈 시작값 — 사용자가 0 을 지우는 마찰 제거. UI 에 prefix '$' + placeholder '0.00'.
  final _cardCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  double get _card => double.tryParse(_cardCtrl.text) ?? 0;
  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _reported => _card + _cash;

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  void _gotoSuccess() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AttendanceSuccessScreen(
          action: AttendanceAction.clockOut,
          userName: widget.userName,
          workedMinutes: widget.workedMinutes,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      await service.submitTipEntry(
        userId: widget.userId,
        pin: widget.pin,
        date: _todayIso(),
        cardTips: _card.toStringAsFixed(2),
        cashTipsKept: _cash.toStringAsFixed(2),
      );
      _gotoSuccess();
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = _humanError(e);
      });
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('Distributed exceeds')) {
      return s.substring(s.indexOf('Distributed'));
    }
    return 'Could not save tip entry. Try again or skip for now.';
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          color: AppColors.accent, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Report tips',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.userName} · ${_todayIso()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MoneyField(
                    label: 'Total credit-card tips',
                    helper: 'Gross amount before sharing with coworkers',
                    controller: _cardCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _MoneyField(
                    label: 'Cash tips kept',
                    helper: 'After splitting with coworkers in person',
                    controller: _cashCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reported on 4070',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '\$${_reported.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can edit distribution to coworkers from the staff app.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _gotoSuccess,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            side:
                                const BorderSide(color: AppColors.border),
                          ),
                          child: const Text(
                            'No tips — Skip & Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit & Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final String helper;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MoneyField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '\$',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
