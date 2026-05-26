/// EarlyClockOutDialog — scheduled_end 보다 이른 clock-out 시 사유 picker.
///
/// mockup 결정 (2026-05-22):
///   - 경고 헤더 (icon + "Early Clock Out" + 남은 시간 + scheduledEnd)
///   - "{name}, why are you leaving early?" + 설명
///   - 5개 사유 라디오 (Feeling unwell / Family emergency / Manager approved /
///     Personal / Other)
///   - Other 선택 시 textarea (max 300자)
///   - Cancel / Submit & Clock Out
///   - Submit 활성: reason 선택 AND (Other 면 detail trim 길이 > 0)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/early_clock_out_reason.dart';
import '../utils/early_clock_out_logic.dart';

/// EarlyClockOutReason → l10n label.
String localizedReasonLabel(AppL10n t, EarlyClockOutReason r) => switch (r) {
      EarlyClockOutReason.feelingUnwell => t.pfEarlyReasonUnwell,
      EarlyClockOutReason.familyEmergency => t.pfEarlyReasonFamily,
      EarlyClockOutReason.managerApproved => t.pfEarlyReasonManager,
      EarlyClockOutReason.personal => t.pfEarlyReasonPersonal,
      EarlyClockOutReason.other => t.pfEarlyReasonOther,
    };

class EarlyClockOutDialog extends StatefulWidget {
  final String userName;
  final String scheduledEnd; // "HH:MM"
  final int remainingMinutes;
  final void Function(EarlyClockOutReason reason, String? detail) onSubmit;
  final VoidCallback onCancel;

  const EarlyClockOutDialog({
    super.key,
    required this.userName,
    required this.scheduledEnd,
    required this.remainingMinutes,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<EarlyClockOutDialog> createState() => _EarlyClockOutDialogState();
}

class _EarlyClockOutDialogState extends State<EarlyClockOutDialog> {
  EarlyClockOutReason? _reason;
  final _detailController = TextEditingController();

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  bool get _canSubmit => canSubmitEarlyClockOut(_reason, _detailController.text);

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(_reason!, detailToSubmit(_reason!, _detailController.text));
  }

  String get _remainingLabel => formatRemainingMinutes(widget.remainingMinutes);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WarningHeader(
                  remainingLabel: _remainingLabel,
                  scheduledEnd: widget.scheduledEnd,
                ),
                const SizedBox(height: 20),
                Text(
                  t.pfEarlyTitle(widget.userName),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.pfEarlyBody,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...EarlyClockOutReason.values.map(_buildReasonOption),
                if (_reason == EarlyClockOutReason.other) ...[
                  const SizedBox(height: 8),
                  _DetailField(
                    controller: _detailController,
                    onChanged: () => setState(() {}),
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
                            side: const BorderSide(color: AppColors.border, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            t.pfEarlyCancel,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                            disabledBackgroundColor: AppColors.warning.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            t.pfEarlySubmit,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
    );
  }

  Widget _buildReasonOption(EarlyClockOutReason r) {
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
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                localizedReasonLabel(AppL10n.of(context), r),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.accent : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningHeader extends StatelessWidget {
  final String remainingLabel;
  final String scheduledEnd;
  const _WarningHeader({required this.remainingLabel, required this.scheduledEnd});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.warning_amber_rounded, size: 26, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppL10n.of(context).pfEarlyHeader,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppL10n.of(context).pfEarlyRemainingLine(remainingLabel, scheduledEnd),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning.withValues(alpha: 0.85),
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
  final VoidCallback onChanged;
  const _DetailField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      autofocus: true,
      maxLength: 300,
      minLines: 2,
      maxLines: 4,
      inputFormatters: [LengthLimitingTextInputFormatter(300)],
      decoration: InputDecoration(
        hintText: AppL10n.of(context).pfEarlyDetailHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 2),
        ),
      ),
    );
  }
}
