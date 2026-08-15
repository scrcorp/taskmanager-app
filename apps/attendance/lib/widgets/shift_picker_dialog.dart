/// ShiftPickerDialog — "이거 아님" 을 눌렀을 때만 열리는 shift 목록 (D14).
///
/// 목록에는 **완료된 shift 도 보여주되 선택은 막는다**(D14). 안 보여주면
/// "내 오전 근무는 어디 갔나" 가 되고, 고르게 두면 서버가 거부해 설명 없는 400 이
/// 뜬다. 보이되 회색 + "Already done" 이 유일하게 말이 되는 조합이다.
///
/// 각 항목의 판정 프리뷰("3h 12m late")는 **서버가 계산한 값**을 그대로 쓴다(R0-1).
/// 잘못 고르면 사유 요구와 급여 확정 게이트로 이어지므로 결과를 먼저 보여준다(D3).

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/identify_response.dart';
import '../utils/shift_pick_logic.dart';
import 'shift_display.dart';

class ShiftPickerDialog extends StatelessWidget {
  final String userName;
  final List<TodayAttendanceItem> items;

  /// 현재 선택된 schedule — 목록에서 강조.
  final String? selectedScheduleId;

  final ValueChanged<TodayAttendanceItem> onPick;
  final VoidCallback onCancel;

  /// 기기가 보는 영업일 라벨 ("YYYY-MM-DD"). 어제 shift 배지 판단용.
  final String? todayOperatingDay;

  /// 왜 다시 고르라고 하는지 (예: 고른 shift 가 후보에서 빠졌다).
  /// 이유 없이 목록만 다시 뜨면 사용자는 앱이 오작동한 것으로 읽는다.
  final String? notice;

  const ShiftPickerDialog({
    super.key,
    required this.userName,
    required this.items,
    required this.onPick,
    required this.onCancel,
    this.selectedScheduleId,
    this.todayOperatingDay,
    this.notice,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
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
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.pfShiftPickerTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.pfShiftPickerBody,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (notice != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notice!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ShiftRow(
                        item: item,
                        selected: item.scheduleId != null &&
                            item.scheduleId == selectedScheduleId,
                        todayOperatingDay: todayOperatingDay,
                        onTap: isShiftSelectable(item)
                            ? () => onPick(item)
                            : null,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onCancel,
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
                        t.pfShiftPickerCancel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class _ShiftRow extends StatelessWidget {
  final TodayAttendanceItem item;
  final bool selected;
  final String? todayOperatingDay;

  /// null 이면 고를 수 없는 항목 — 탭이 막히고 회색으로 그려진다.
  final VoidCallback? onTap;

  const _ShiftRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.todayOperatingDay,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final enabled = onTap != null;
    final ineligible = shiftIneligibleText(t, item);
    final isYesterday = isPreviousOperatingDay(item, todayOperatingDay);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.bg.withValues(alpha: 0.5)
              : (selected ? AppColors.accentBg : AppColors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected && enabled ? AppColors.accent : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shiftTimeRangeText(t, item),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: enabled
                                ? AppColors.text
                                : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isYesterday) ...[
                        const SizedBox(width: 8),
                        const ShiftDayBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (ineligible != null)
                    Text(
                      ineligible,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    ShiftPreviewLine(preview: item.clockInPreview),
                ],
              ),
            ),
            if (enabled)
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 26,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
