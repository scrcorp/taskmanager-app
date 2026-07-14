/// 근무 가용성 미리보기 스트립 (재사용 위젯)
///
/// 7칸 타일(일→토) + 짧은 요약을 한 줄로 렌더한다. 원래 My Page 카드 전용이었으나
/// Settings 화면의 "Work Availability" 행에서도 재사용하기 위해 별도 위젯으로 분리.
///
/// [days] 가 null 이면 로딩/실패 상태로 회색 placeholder 타일을 표시하고,
/// [placeholderText] 가 있으면 그 문구(없으면 "Loading…")를 요약 자리에 보여준다.
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/availability.dart';

class AvailabilityStrip extends StatelessWidget {
  final List<AvailabilityDay>? days;
  final String? placeholderText;

  const AvailabilityStrip({super.key, required this.days, this.placeholderText});

  /// 요일 인덱스(0=Sun..6=Sat) → 3글자 로컬라이즈 약어
  String _shortWeekday(AppL10n t, int day) {
    switch (day) {
      case 0:
        return t.weekdayShortSunday;
      case 1:
        return t.weekdayShortMonday;
      case 2:
        return t.weekdayShortTuesday;
      case 3:
        return t.weekdayShortWednesday;
      case 4:
        return t.weekdayShortThursday;
      case 5:
        return t.weekdayShortFriday;
      default:
        return t.weekdayShortSaturday;
    }
  }

  /// 근무일(off 아님)을 연속 구간으로 묶어 "Mon–Tue, Thu–Fri" 형태로 요약.
  String _summary(AppL10n t, List<AvailabilityDay> days) {
    final active = <int>[
      for (var i = 0; i < days.length; i++)
        if (days[i].state != AvailabilityState.off) i,
    ];
    if (active.isEmpty) return t.workAvailabilityAllOff;

    final runs = <String>[];
    var start = active.first;
    var prev = active.first;
    for (var k = 1; k <= active.length; k++) {
      final cur = k < active.length ? active[k] : -99;
      if (cur == prev + 1) {
        prev = cur;
        continue;
      }
      runs.add(start == prev
          ? _shortWeekday(t, start)
          : '${_shortWeekday(t, start)}–${_shortWeekday(t, prev)}');
      start = cur;
      prev = cur;
    }
    return t.workAvailabilitySummary(active.length, runs.join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final data = days;
    final summaryText = data == null
        ? (placeholderText ?? t.workAvailabilityLoading)
        : _summary(t, data);

    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              _AvailTile(day: data == null ? null : data[i]),
            ],
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            summaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// 미리보기 스트립의 개별 요일 타일.
///   off  = 대각선 해치(텍스처) / range = sky + 시계 / full = purple
///   day == null = 로딩/실패용 회색 placeholder
class _AvailTile extends StatelessWidget {
  final AvailabilityDay? day;
  const _AvailTile({required this.day});

  static const _sky = Color(0xFF0EA5E9);
  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    const w = 22.0;
    const h = 24.0;
    final radius = BorderRadius.circular(6);

    final state = day?.state;

    if (day == null) {
      // placeholder (로딩/실패)
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: radius,
        ),
      );
    }

    switch (state!) {
      case AvailabilityState.off:
        return ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            size: const Size(w, h),
            painter: _HatchPainter(),
          ),
        );
      case AvailabilityState.range:
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: _sky, borderRadius: radius),
          child: const Icon(Icons.schedule, size: 13, color: Colors.white),
        );
      case AvailabilityState.full:
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: _purple, borderRadius: radius),
        );
    }
  }
}

/// off 타일용 대각선 해치 페인터 (배경 #F8FAFC + #CBD5E1 선 + 얇은 테두리)
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    // 45도 대각선을 4px 간격으로 반복 (RoutineStrip OFF_HATCH 규칙)
    const step = 4.0;
    for (var d = -size.height; d < size.width; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), line);
    }

    final border = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
        Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1), border);
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
