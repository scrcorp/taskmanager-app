/// shift 표시 문구 — pure logic(`shift_pick_logic.dart`) 과 l10n 사이의 얇은 층.
///
/// 서버는 표시 문자열을 내려보내지 않는다(R0-3). 숫자·종류만 받아서 문구는 여기서
/// 만든다 — 앱은 en/es 두 벌이고 콘솔은 영어 하드코딩이라 표시 소유권이 클라에 있다.
library;

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/identify_response.dart';
import '../utils/shift_pick_logic.dart';

/// "09:00 – 13:00". 시각을 모르면 "Time not set".
String shiftTimeRangeText(AppL10n t, TodayAttendanceItem item) {
  final start = item.scheduledStartDisplay;
  final end = item.scheduledEndDisplay;
  if (start == null || start.isEmpty || end == null || end.isEmpty) {
    return t.pfShiftTimeUnknown;
  }
  return t.pfShiftTimeRange(start, end);
}

/// "3h 12m late" / "2h early" / "On time". unknown 이면 null → 줄 자체를 숨긴다.
///
/// 숫자가 앞이다(`Late 3h 12m` 아님) — 목록에서 숫자가 먼저 눈에 들어와야
/// 오선택을 막는다(계약 §1.4).
String? shiftPreviewText(AppL10n t, ClockInPreview? preview) {
  final p = shiftPreviewOf(preview);
  switch (p.kind) {
    case ShiftPreviewKind.late:
      return t.pfShiftLate(formatShiftDuration(p.minutes));
    case ShiftPreviewKind.early:
      return t.pfShiftEarly(formatShiftDuration(p.minutes));
    case ShiftPreviewKind.onTime:
      return t.pfShiftOnTime;
    case ShiftPreviewKind.unknown:
      return null;
  }
}

/// 프리뷰 색 — late/early 는 경고, on_time 은 정상.
Color shiftPreviewColor(ClockInPreview? preview) {
  switch (shiftPreviewOf(preview).kind) {
    case ShiftPreviewKind.late:
      return AppColors.danger;
    case ShiftPreviewKind.early:
      return AppColors.warning;
    case ShiftPreviewKind.onTime:
      return AppColors.success;
    case ShiftPreviewKind.unknown:
      return AppColors.textSecondary;
  }
}

/// 못 고르는 이유 라벨. 고를 수 있으면 null.
String? shiftIneligibleText(AppL10n t, TodayAttendanceItem item) {
  if (item.clockInEligible) return null;
  switch (item.ineligibleReason) {
    case kIneligibleAlreadyClockedIn:
      return t.pfShiftClockedIn;
    case kIneligibleAlreadyCompleted:
      return t.pfShiftAlreadyDone;
    case kIneligibleOutsideOperatingWindow:
      // 직원이 스스로 고칠 수 없다 — 영업일을 바꿔야 하는 일이라 매니저를 가리킨다.
      return t.pfShiftOutsideWindow;
    default:
      // 서버가 새 이유를 추가했는데 앱이 모르는 경우. 문구를 지어내지 않고
      // "고를 수 없다" 만 알린다 — 완료 표시가 가장 가까운 의미다.
      return t.pfShiftAlreadyDone;
  }
}

/// 판정 프리뷰 한 줄 + (필요하면) "Reason required" 배지.
///
/// [big] 은 기본 제시 카드용 — §1.8 이 요구하는 **본문 크기** 노출이다.
/// 새 fallback 규칙이 오전 no_show 를 먼저 제시하므로, 오판을 막는 유일한
/// 방어선이 이 줄의 가시성이다. 작은 회색 캡션으로 만들면 안 된다.
class ShiftPreviewLine extends StatelessWidget {
  final ClockInPreview? preview;
  final bool big;

  const ShiftPreviewLine({super.key, required this.preview, this.big = false});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final text = shiftPreviewText(t, preview);
    if (text == null) return const SizedBox.shrink();
    final color = shiftPreviewColor(preview);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: big ? 20 : 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        if (preview?.reasonRequired == true) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.pfShiftReasonRequired,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Yesterday" 배지 — 어제 영업일 shift 를 고를 때만 (D4).
///
/// 이게 없으면 야간조가 어제 shift 를 오늘 것으로 착각하고 고른다.
class ShiftDayBadge extends StatelessWidget {
  const ShiftDayBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppL10n.of(context).pfShiftYesterday,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
