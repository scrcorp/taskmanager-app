/// EarlyClockInDialog — 예정 시작보다 이른 출근을 강행할 때의 사유 입력.
///
/// 왜 있는가: 매니저/SV 가 현장에 없을 때 "좀 더 일찍 와달라"로 온 직원이
/// 출근을 못 찍는 상황이 실제로 있었다. 서버는 이제 차단 대신 사유를 요구하고
/// (code=early_clock_in_reason_required), 이 화면이 그 사유를 받는다.
///
/// 형태는 BreakReasonDialog / EarlyClockOutDialog 와 동일한 preset + Other 패턴 —
/// 키오스크는 터치 환경이라 자유 입력만 두면 실질적으로 못 쓴다.
///
/// "예정보다 얼마나 이른지" 를 헤더에 크게 보여준다. 서버가 시간 상한을 두지
/// 않으므로(몇 시간 전에 부를지 예측 불가), 다음날 shift 오선택 같은 오조작을
/// 사용자가 알아채는 장치가 이 문구뿐이다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/early_clock_in_reason.dart';
import '../utils/early_clock_in_logic.dart';

/// EarlyClockInReason → l10n label.
String localizedEarlyClockInLabel(AppL10n t, EarlyClockInReason r) => switch (r) {
      EarlyClockInReason.askedToComeEarly => t.pfEarlyInAsked,
      EarlyClockInReason.coveringForSomeone => t.pfEarlyInCovering,
      EarlyClockInReason.storeNeedsHelp => t.pfEarlyInStoreHelp,
      EarlyClockInReason.other => t.pfEarlyInOther,
    };

class EarlyClockInDialog extends StatefulWidget {
  final String userName;

  /// 예정 시작보다 몇 분 이른지 (서버 detail.minutes_early).
  final int minutesEarly;

  final void Function(String reason) onSubmit;
  final VoidCallback onCancel;

  /// 서버가 거부했을 때 표시할 inline 에러 (raw 메시지 대신 화면 안에서 안내).
  final String? errorText;

  const EarlyClockInDialog({
    super.key,
    required this.userName,
    required this.minutesEarly,
    required this.onSubmit,
    required this.onCancel,
    this.errorText,
  });

  @override
  State<EarlyClockInDialog> createState() => _EarlyClockInDialogState();
}

class _EarlyClockInDialogState extends State<EarlyClockInDialog> {
  EarlyClockInReason? _reason;
  final _detailController = TextEditingController();

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  bool get _canSubmit => canSubmitEarlyClockIn(_reason, _detailController.text);

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(
      earlyClockInReasonToSubmit(_reason!, _detailController.text),
    );
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
                  _EarlyHeader(minutesEarly: widget.minutesEarly),
                  const SizedBox(height: 20),
                  Text(
                    t.pfEarlyInTitle(widget.userName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.pfEarlyInBody,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...EarlyClockInReason.values.map(_buildReasonOption),
                  if (_reason == EarlyClockInReason.other) ...[
                    const SizedBox(height: 8),
                    _DetailField(
                      controller: _detailController,
                      hint: t.pfEarlyInOtherHint,
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
                              t.pfEarlyInCancel,
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
                              t.pfEarlyInSubmit,
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

  Widget _buildReasonOption(EarlyClockInReason r) {
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
                  localizedEarlyClockInLabel(AppL10n.of(context), r),
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

class _EarlyHeader extends StatelessWidget {
  final int minutesEarly;
  const _EarlyHeader({required this.minutesEarly});

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
              Icons.schedule_rounded,
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
                  t.pfEarlyInHeader,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.pfEarlyInEarlyBy(formatEarlyBy(minutesEarly)),
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
