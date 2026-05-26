/// StaffDetailPanel — Schedule screen 우측 패널.
///
/// row null 이면 placeholder. on_break 면 break 정보 박스 + 정책 hint.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../providers/attendance_dashboard_provider.dart';
import '../utils/staff_status_utils.dart';

class StaffDetailPanel extends StatelessWidget {
  final TodayStaffRow? row;
  final DateTime? now;

  const StaffDetailPanel({super.key, required this.row, this.now});

  @override
  Widget build(BuildContext context) {
    final r = row;
    if (r == null) return const _Empty();
    return _Detail(row: r, now: now ?? DateTime.now());
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.view_list_rounded, size: 28, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pick a staff to see details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap any block on the left',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final TodayStaffRow row;
  final DateTime now;
  const _Detail({required this.row, required this.now});

  @override
  Widget build(BuildContext context) {
    final tokens = _statusTokens(row.status);
    final initials = _initials(row.userName);
    final isBreak = row.status == 'on_break' && row.currentBreak != null;
    final breakInfo = isBreak
        ? breakProgress(
            row.currentBreak!.breakType,
            now.difference(row.currentBreak!.startedAt).inMinutes,
          )
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar + name + status
          Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: tokens.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: tokens.fg,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                row.userName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel(row.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tokens.fg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Break info box (priority)
          if (breakInfo != null)
            _BreakInfoBox(
              label: breakLabel(row.currentBreak!.breakType),
              elapsedMinutes: breakInfo.elapsedMinutes,
              hint: breakInfo.hint,
              warn: breakInfo.state != BreakState.within,
            ),
          if (breakInfo != null) const SizedBox(height: 16),

          // Schedule + clock rows
          _DetailRow(label: 'Scheduled', value: _schedRange(row)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Clock In', value: row.clockInDisplay ?? '—'),
          const SizedBox(height: 8),
          _DetailRow(label: 'Clock Out', value: row.clockOutDisplay ?? '—'),
        ],
      ),
    );
  }
}

String _schedRange(TodayStaffRow row) {
  final s = row.scheduledStartDisplay;
  final e = row.scheduledEndDisplay;
  if (s == null && e == null) return 'No schedule';
  return '${s ?? '—'} – ${e ?? '—'}';
}

class _BreakInfoBox extends StatelessWidget {
  final String label;
  final int elapsedMinutes;
  final String hint;
  final bool warn;
  const _BreakInfoBox({
    required this.label,
    required this.elapsedMinutes,
    required this.hint,
    required this.warn,
  });

  @override
  Widget build(BuildContext context) {
    final bg = warn ? AppColors.dangerBg : AppColors.warningBg;
    final fg = warn ? AppColors.danger : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${elapsedMinutes}m elapsed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

({Color bg, Color fg}) _statusTokens(String status) {
  switch (status) {
    case 'working':
      return (bg: AppColors.successBg, fg: AppColors.success);
    case 'on_break':
      return (bg: AppColors.warningBg, fg: AppColors.warning);
    case 'upcoming':
    case 'soon':
      return (bg: AppColors.accentBg, fg: AppColors.accent);
    case 'late':
      return (bg: AppColors.warningBg, fg: AppColors.warning);
    case 'no_show':
      return (bg: AppColors.dangerBg, fg: AppColors.danger);
    case 'clocked_out':
      return (bg: AppColors.bg, fg: AppColors.textMuted);
    default:
      return (bg: AppColors.bg, fg: AppColors.textMuted);
  }
}

String _initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
}
