/// StaffBlock — Schedule screen 의 compact 블록.
///
/// 이니셜 + 이름 + 1줄 서브 (상태별 핵심 정보). 클릭 시 onTap 호출.
/// selected=true 면 accent border + bg.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../providers/attendance_dashboard_provider.dart';
import '../utils/staff_status_utils.dart';

class StaffBlock extends StatelessWidget {
  final TodayStaffRow row;
  final bool selected;
  final VoidCallback onTap;

  const StaffBlock({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = _statusTokens(row.status);
    final initials = _initialsOf(row.userName);
    final subline = staffBlockSubline(row);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBg : AppColors.bg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tokens.fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subline,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상태별 색 토큰 (background + foreground).
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

String _initialsOf(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  final initials = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
  return initials.toUpperCase();
}
