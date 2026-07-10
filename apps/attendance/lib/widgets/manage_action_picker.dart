/// Manage 액션 선택 중앙 모달 (Issue 10 Step 4) — 우측 패널 [Actions] 로 열림.
///
/// 상태별 clock 액션 타일을 나열. 선택 → onPick(action) → Action Modal(시간/사유).

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../providers/attendance_manage_provider.dart';
import '../screens/attendance/attendance_manage_action_modal.dart';
import '../utils/manage_status_colors.dart';
import '../utils/manage_status_utils.dart';

class ManageActionPicker extends StatelessWidget {
  final AdminScheduleRow row;
  final DateTime now;
  final ValueChanged<AdminAction> onPick;

  const ManageActionPicker({super.key, required this.row, required this.now, required this.onPick});

  /// showDialog 헬퍼 — 선택된 액션 반환 (취소면 null).
  static Future<AdminAction?> show(BuildContext context, {required AdminScheduleRow row, required DateTime now}) {
    return showDialog<AdminAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => ManageActionPicker(
        row: row,
        now: now,
        onPick: (a) => Navigator.of(ctx).pop(a),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stateC = manageStateColors(row.state);
    final actions = adminActionsForState(row.state);
    final soon = isManageSoon(row.state, row.anomalies, row.startHHmm, now, startAt: row.startAt);

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: stateC.bg, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text(_initials(row.userName),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: stateC.fg)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _chip(manageStateLabel(row.state).toUpperCase(), stateC.bg, stateC.fg),
                          if (soon) _chip('SOON', manageSoonColors.bg, manageSoonColors.fg),
                          for (final a in row.anomalies)
                            _chip(manageAnomalyLabel(a).toUpperCase(), manageAnomalyColors(a).bg, manageAnomalyColors(a).fg),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 액션 타일
              if (actions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No clock actions for this status.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                )
              else
                for (final a in actions) ...[
                  _ActionTile(action: a, onTap: () => onPick(a)),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.4)),
      );
}

class _ActionTile extends StatelessWidget {
  final AdminAction action;
  final VoidCallback onTap;
  const _ActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = action.color;
    return Material(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(action.icon, size: 24, color: c),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
                    const SizedBox(height: 2),
                    Text(action.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
