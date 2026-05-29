/// 공용 디테일 패널 (Issue 10 통합) — staff schedule / manage 홈 우측 공용.
///
/// 액션 콜백(onActions/onEdit/onDelete)이 모두 null 이면 읽기 전용(액션 영역 숨김).
/// manage 는 콜백 전달, staff schedule 은 미전달.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../models/schedule_staff_view.dart';
import '../providers/attendance_manage_provider.dart' show ManageBreak;
import '../utils/manage_status_colors.dart';
import '../utils/manage_status_utils.dart';
import '../utils/staff_status_utils.dart' show breakLabel, breakProgress, BreakState;
import 'schedule_staff_card.dart' show scheduleMinsSince, scheduleDurLabel;

class ScheduleStaffDetailPanel extends StatelessWidget {
  final ScheduleStaffView? view;
  final DateTime now;
  final VoidCallback? onActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ScheduleStaffDetailPanel({
    super.key,
    required this.view,
    required this.now,
    this.onActions,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final v = view;
    if (v == null) return const _Empty();
    return _Detail(view: v, now: now, onActions: onActions, onEdit: onEdit, onDelete: onDelete);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.view_list_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Pick a staff to see details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Tap any block on the left.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final ScheduleStaffView view;
  final DateTime now;
  final VoidCallback? onActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _Detail({required this.view, required this.now, this.onActions, this.onEdit, this.onDelete});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stateC = manageStateColors(view.state);
    final soon = isManageSoon(view.state, view.anomalies, view.scheduledStart, now);
    final hasActions = onActions != null || onEdit != null || onDelete != null;

    String? workedSub;
    if (view.state == 'working' && view.clockIn != null) {
      workedSub = '${scheduleDurLabel(scheduleMinsSince(now, view.clockIn))} worked';
    }

    final chips = <Widget>[
      _chip(manageStateLabel(view.state).toUpperCase(), stateC.bg, stateC.fg),
      if (soon) _chip('SOON', manageSoonColors.bg, manageSoonColors.fg),
      for (final a in view.anomalies)
        _chip(manageAnomalyLabel(a).toUpperCase(), manageAnomalyColors(a).bg, manageAnomalyColors(a).fg),
    ];

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: stateC.bg, borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          child: Text(_initials(view.name),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: stateC.fg)),
        ),
        const SizedBox(height: 12),
        Text(view.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
        if (view.roleLabel != null) ...[
          const SizedBox(height: 2),
          Text(view.roleLabel!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: chips),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Scheduled', '${view.scheduledStart ?? '--:--'} – ${view.scheduledEnd ?? '--:--'}'),
                const SizedBox(height: 6),
                _row('Clock In', view.clockIn ?? '—', sub: workedSub),
                const SizedBox(height: 6),
                _row('Clock Out', view.clockOut ?? '—'),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 6),
                  child: Text('BREAKS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
                ),
                if (view.breaks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text('No breaks taken.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  )
                else
                  ...view.breaks.map((b) => _BreakRow(entry: b, now: now)),
              ],
            ),
          ),
        ),
        if (hasActions) ...[
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          if (onActions != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onActions,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          if (onActions != null && (onEdit != null || onDelete != null)) const SizedBox(height: 8),
          if (onEdit != null || onDelete != null)
            Row(
              children: [
                if (onEdit != null)
                  Expanded(child: _SecondaryButton(icon: Icons.edit_outlined, label: 'Edit', color: AppColors.accent, onTap: onEdit)),
                if (onEdit != null && onDelete != null) const SizedBox(width: 8),
                if (onDelete != null)
                  Expanded(child: _SecondaryButton(icon: Icons.delete_outline_rounded, label: 'Delete', color: AppColors.danger, onTap: onDelete)),
              ],
            ),
        ],
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5)),
      );

  Widget _row(String label, String value, {String? sub}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text, fontFeatures: [FontFeature.tabularFigures()])),
              if (sub != null)
                Text(sub, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  final ManageBreak entry;
  final DateTime now;
  const _BreakRow({required this.entry, required this.now});

  int _spanMinutes(String start, String end) {
    final s = start.split(':');
    final e = end.split(':');
    final sm = (int.tryParse(s[0]) ?? 0) * 60 + (int.tryParse(s.length > 1 ? s[1] : '0') ?? 0);
    final em = (int.tryParse(e[0]) ?? 0) * 60 + (int.tryParse(e.length > 1 ? e[1] : '0') ?? 0);
    final d = em - sm;
    return d < 0 ? 0 : d;
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = entry.end == null;
    final durMin = inProgress ? scheduleMinsSince(now, entry.start) : _spanMinutes(entry.start, entry.end!);
    final prog = inProgress ? breakProgress(entry.type, durMin) : null;
    final over = prog != null && prog.state != BreakState.within && prog.state != BreakState.tooShort;
    final fg = inProgress ? (over ? AppColors.danger : AppColors.warning) : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.type == 'paid_10min' ? Icons.local_cafe_outlined : Icons.restaurant_outlined, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(breakLabel(entry.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ),
                    if (inProgress) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: fg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
                        child: Text('IN PROGRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.start} – ${inProgress ? 'now' : entry.end}${inProgress && prog != null ? '  ·  ${prog.hint}' : ''}',
                  style: TextStyle(fontSize: 11, color: inProgress ? fg : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(scheduleDurLabel(durMin),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _SecondaryButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
