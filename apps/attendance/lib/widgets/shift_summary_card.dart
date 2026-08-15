/// ShiftSummaryCard — "지금 이 shift 로 찍습니다" 기본 제시 카드 (D14).
///
/// 왜 카드 하나인가: 후보가 2개여도 **목록을 먼저 띄우지 않는다.** 정상 출근자는
/// 탭이 늘면 안 된다. 기본값 하나를 보여주고, 아니면 "Not this one" 으로 바꾼다.
///
/// 판정 프리뷰("3h 12m late")는 **본문 크기**로 노출한다(계약 §1.8).
/// 서버 fallback 이 "시간순 첫 미출근" 으로 바뀌면서, 저녁 조만 정상 출근하는 날에도
/// 오전 no_show 가 먼저 제시된다. 오판의 방향이 뒤집힐 뿐이라 유일한 방어선이
/// 이 줄의 가시성이다 — 작은 회색 캡션으로 만들면 이 트랙이 원점으로 돌아간다.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/identify_response.dart';
import '../utils/shift_pick_logic.dart';
import 'shift_display.dart';

class ShiftSummaryCard extends StatelessWidget {
  final TodayAttendanceItem item;

  /// "Not this one" 을 누를 수 있는가 — 후보가 2개 이상일 때만 (D1).
  final VoidCallback? onChange;

  /// 기기가 보는 영업일 라벨 ("YYYY-MM-DD"). 어제 shift 배지 판단용.
  final String? todayOperatingDay;

  const ShiftSummaryCard({
    super.key,
    required this.item,
    this.onChange,
    this.todayOperatingDay,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final ineligible = shiftIneligibleText(t, item);
    final isYesterday = isPreviousOperatingDay(item, todayOperatingDay);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
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
                    Text(
                      t.pfShiftCardHeader,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (isYesterday) ...[
                      const SizedBox(width: 8),
                      const ShiftDayBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  shiftTimeRangeText(t, item),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                if (ineligible != null)
                  Text(
                    ineligible,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ShiftPreviewLine(preview: item.clockInPreview, big: true),
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onChange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Text(
                  t.pfShiftNotThisOne,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
