/// BreakReasonDialog — 허용 시간을 넘긴 break 를 끝낼 때의 사유 입력.
///
/// 왜 있는가: 서버 정책(`break_end_policy`)은 unpaid_meal 35분 이상이면 reason 을
/// 필수로 요구한다. 이 화면이 없으면 스태프는 키오스크에서 휴식을 끝낼 수 없다.
///
/// 형태는 EarlyClockOutDialog 와 동일한 preset + Other(자유입력) 패턴 —
/// 키오스크는 터치 환경이라 자유 입력만 두면 실질적으로 못 쓴다.
/// 프리셋 문구는 "왜 길어졌는가" 전용이다 (early clock-out 사유와 다름).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/break_overrun_reason.dart';
import '../utils/break_reason_logic.dart';

/// BreakOverrunReason → l10n label.
String localizedBreakReasonLabel(AppL10n t, BreakOverrunReason r) => switch (r) {
      BreakOverrunReason.forgotToEnd => t.pfBreakReasonForgot,
      BreakOverrunReason.managerApproved => t.pfBreakReasonManager,
      BreakOverrunReason.personalEmergency => t.pfBreakReasonEmergency,
      BreakOverrunReason.waitingForCoverage => t.pfBreakReasonCoverage,
      BreakOverrunReason.other => t.pfBreakReasonOther,
    };

class BreakReasonDialog extends StatefulWidget {
  final String userName;
  final int elapsedMinutes;
  final void Function(String reason) onSubmit;
  final VoidCallback onCancel;

  /// 서버가 거부했을 때 표시할 inline 에러 (raw 메시지 대신 화면 안에서 안내).
  final String? errorText;

  const BreakReasonDialog({
    super.key,
    required this.userName,
    required this.elapsedMinutes,
    required this.onSubmit,
    required this.onCancel,
    this.errorText,
  });

  @override
  State<BreakReasonDialog> createState() => _BreakReasonDialogState();
}

class _BreakReasonDialogState extends State<BreakReasonDialog> {
  BreakOverrunReason? _reason;
  final _detailController = TextEditingController();

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  bool get _canSubmit => canSubmitBreakReason(_reason, _detailController.text);

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(breakReasonToSubmit(_reason!, _detailController.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OverrunHeader(elapsedMinutes: widget.elapsedMinutes),
                  const SizedBox(height: 20),
                  Text(
                    t.pfBreakReasonTitle(widget.userName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.pfBreakReasonBody,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...BreakOverrunReason.values.map(_buildReasonOption),
                  if (_reason == BreakOverrunReason.other) ...[
                    const SizedBox(height: 8),
                    _DetailField(
                      controller: _detailController,
                      hint: t.pfBreakReasonOtherHint,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  if (widget.errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.errorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: widget.onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.border,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              t.pfBreakReasonCancel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.warning
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              t.pfBreakReasonSubmit,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
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

  Widget _buildReasonOption(BreakOverrunReason r) {
    final selected = _reason == r;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _reason = r),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBg : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizedBreakReasonLabel(AppL10n.of(context), r),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.accent : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverrunHeader extends StatelessWidget {
  final int elapsedMinutes;
  const _OverrunHeader({required this.elapsedMinutes});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.timer_off_rounded,
              size: 26,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.pfBreakReasonHeader,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.pfBreakReasonElapsed(elapsedMinutes),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  const _DetailField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      maxLength: 300,
      inputFormatters: [LengthLimitingTextInputFormatter(300)],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }
}
