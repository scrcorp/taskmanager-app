/// 매장 현지 시계 — 공용 위젯 (Issue 10 Step 6).
///
/// 변환은 공용 유틸 toStoreClock 사용. 키오스크는 디바이스 위치와 무관하게
/// 매장 TZ wall-clock 으로 표시. 부모가 now(보통 1초 틱)를 넘긴다.
///
/// 재사용 파라미터: 색(color/labelColor), 크기(fontSize/labelFontSize),
/// 24시간제(use24Hour), 초 표시(showSeconds), 지역 라벨(tzLabel — null 이면 미표시).
/// 배치(위치)는 부모가 결정한다.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';
import 'package:intl/intl.dart';

import '../utils/store_time.dart';

class StoreClock extends StatelessWidget {
  final DateTime now; // 부모 틱 (local DateTime — toStoreClock 이 utc 변환)
  final int? offsetMinutes;
  final String? tzLabel; // null/빈값 이면 라벨 미표시
  final double fontSize;
  final Color? color; // 기본 accent
  final bool use24Hour; // 기본 24시간제
  final bool showSeconds; // 기본 초 표시
  final Color? labelColor; // 기본 textMuted
  final double? labelFontSize; // 기본 13

  const StoreClock({
    super.key,
    required this.now,
    required this.offsetMinutes,
    this.tzLabel,
    this.fontSize = 40,
    this.color,
    this.use24Hour = true,
    this.showSeconds = true,
    this.labelColor,
    this.labelFontSize,
  });

  /// IANA tz ("America/Los_Angeles") → 짧은 표시 라벨 ("Los Angeles").
  static String? labelFromIana(String? iana) {
    if (iana == null || iana.isEmpty) return null;
    final last = iana.split('/').last;
    return last.replaceAll('_', ' ');
  }

  String get _pattern {
    if (use24Hour) return showSeconds ? 'HH:mm:ss' : 'HH:mm';
    return showSeconds ? 'h:mm:ss a' : 'h:mm a';
  }

  @override
  Widget build(BuildContext context) {
    final storeNow = toStoreClock(now, offsetMinutes);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          DateFormat(_pattern).format(storeNow),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.accent,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
        if (tzLabel != null && tzLabel!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            tzLabel!,
            style: TextStyle(
              fontSize: labelFontSize ?? 13,
              fontWeight: FontWeight.w700,
              color: labelColor ?? AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
