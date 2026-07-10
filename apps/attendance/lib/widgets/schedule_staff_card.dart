/// 공용 직원 카드 (Issue 10 통합) — staff schedule / manage 홈 좌측 섹션 공용.
///
/// 이니셜 + 이름 + state 배지(breaking 만) + anomaly 칩 + soon 칩 + 스케줄·clock 1줄.
/// ScheduleStaffView 기반이라 두 화면이 동일 카드를 쓴다.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../models/schedule_staff_view.dart';
import '../utils/manage_status_colors.dart';
import '../utils/manage_status_utils.dart';

int scheduleMinsSince(DateTime now, String? hhmm) {
  if (hhmm == null || !hhmm.contains(':')) return 0;
  final p = hhmm.split(':');
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return 0;
  final start = DateTime(now.year, now.month, now.day, h, m);
  final diff = now.difference(start).inMinutes;
  // 자정 넘김: 이벤트(출근/휴식 시작)가 어제 밤이면 diff가 음수 —
  // '0m'으로 클램프하지 말고 +24h wrap (24h 미만 근무 전제).
  if (diff < 0) {
    final wrapped = diff + 24 * 60;
    return wrapped < 0 ? 0 : wrapped;
  }
  return diff;
}

String scheduleDurLabel(int mins) =>
    mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m';

class ScheduleStaffCard extends StatelessWidget {
  final ScheduleStaffView view;
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;

  const ScheduleStaffCard({
    super.key,
    required this.view,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  String get _timeline {
    final sched = '${view.scheduledStart ?? '--:--'}–${view.scheduledEnd ?? '--:--'}';
    switch (view.state) {
      case 'working':
        final inn = view.clockIn;
        return inn != null ? '$sched · in $inn · ${scheduleDurLabel(scheduleMinsSince(now, inn))}' : sched;
      case 'breaking':
        final active = view.breaks.where((b) => b.inProgress).toList();
        final bm = active.isNotEmpty ? ' · break ${scheduleDurLabel(scheduleMinsSince(now, active.first.start))}' : '';
        return '$sched · in ${view.clockIn ?? '—'}$bm';
      case 'done':
        return '$sched · ${view.clockIn ?? '—'}–${view.clockOut ?? '—'}';
      default:
        return sched;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stateC = manageStateColors(view.state);
    final showStateBadge = view.state == 'breaking';
    final soon = isManageSoon(view.state, view.anomalies, view.scheduledStart, now, startAt: view.startAt);

    final chips = <Widget>[];
    if (showStateBadge) chips.add(_chip(manageStateLabel(view.state), stateC.bg, stateC.fg));
    if (soon) chips.add(_chip('Soon', manageSoonColors.bg, manageSoonColors.fg));
    for (final a in view.anomalies) {
      final c = manageAnomalyColors(a);
      chips.add(_chip(manageAnomalyLabel(a), c.bg, c.fg));
    }

    return Material(
      color: selected ? AppColors.accentBg : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: stateC.bg, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(_initials(view.name),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: stateC.fg)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(view.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ...chips.expand((c) => [c, const SizedBox(width: 4)]).toList()..removeLast(),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(_timeline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
      );
}
