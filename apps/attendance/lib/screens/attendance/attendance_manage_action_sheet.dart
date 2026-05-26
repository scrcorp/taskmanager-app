/// 관리자 모드 카드 탭 시 열리는 액션 시트.
///
/// 상단: 직원 헤더
/// 중앙: 현재 상태에 맞는 큼직한 직접 액션 (Clock In/Out, Break, End Break,
///        Undo Clock-in, Undo Clock-out) — 각 액션 탭 시 시간/사유 모달이 열린다.
/// 하단: Edit / Delete (보조 액션)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import 'attendance_manage_action_modal.dart';
import 'attendance_manage_home_screen.dart' show extractApiError;
import 'attendance_manage_schedule_edit_screen.dart';

class AttendanceManageActionSheet extends ConsumerStatefulWidget {
  final AdminScheduleRow row;

  /// 시트 내부 작업이 끝날 때마다 외부 목록 새로고침 콜백.
  final Future<void> Function() onChanged;

  const AttendanceManageActionSheet({
    super.key,
    required this.row,
    required this.onChanged,
  });

  @override
  ConsumerState<AttendanceManageActionSheet> createState() =>
      _AttendanceManageActionSheetState();
}

class _AttendanceManageActionSheetState
    extends ConsumerState<AttendanceManageActionSheet> {
  bool _busy = false;

  Future<void> _runAction(AdminAction action) async {
    final applied = await AttendanceManageActionModal.show(
      context,
      action: action,
      row: widget.row,
    );
    if (!mounted) return;
    if (applied) {
      await widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop(); // close sheet
    }
  }

  Future<void> _openEdit() async {
    Navigator.of(context).pop();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            AttendanceManageScheduleEditScreen(existing: widget.row),
      ),
    );
    await widget.onChanged();
  }

  Future<void> _confirmDelete() async {
    final ok = await AppModal.show(
      context,
      title: 'Delete Schedule?',
      message:
          '${widget.row.userName} · ${widget.row.startHHmm ?? '?'} – ${widget.row.endHHmm ?? '?'}',
      type: ModalType.confirm,
      confirmText: 'Delete',
    );
    if (ok != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      await service.manageDeleteSchedule(widget.row.scheduleId);
      await widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppModal.show(
        context,
        title: 'Delete Failed',
        message: extractApiError(e, 'Could not delete schedule.'),
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final status = row.attendanceStatus ?? '';
    final isWorking = status == 'working' || status == 'late';
    final isOnBreak = status == 'on_break';
    final isClockedOut = status == 'clocked_out';
    final isUpcoming =
        status == 'upcoming' || status == 'soon' || status.isEmpty;
    final isNoShow = status == 'no_show';

    final actions = <AdminAction>[];
    if (isUpcoming || isNoShow) actions.add(AdminAction.clockIn);
    if (isWorking) {
      actions
        ..add(AdminAction.clockOut)
        ..add(AdminAction.break10min)
        ..add(AdminAction.breakMeal);
    }
    if (isOnBreak) {
      actions
        ..add(AdminAction.endBreak)
        ..add(AdminAction.clockOut);
    }
    if (isWorking || isOnBreak) actions.add(AdminAction.undoClockIn);
    if (isClockedOut) actions.add(AdminAction.reopenShift);

    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            _header(row, status),
            const SizedBox(height: 20),
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No clock actions available for status "$status".',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final a in actions) ...[
                    _BigActionTile(
                      action: a,
                      onTap: _busy ? null : () => _runAction(a),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecondaryAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit Schedule',
                    color: AppColors.accent,
                    onTap: _busy ? null : _openEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: AppColors.danger,
                    onTap: _busy ? null : _confirmDelete,
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(AdminScheduleRow row, String status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            _initial(row.userName),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${row.startHHmm ?? '--:--'} – ${row.endHHmm ?? '--:--'}'
                '${row.workRoleLabel != null ? '  ·  ${row.workRoleLabel}' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Current: ${status.toUpperCase()}'
                  '${row.clockInDisplay != null ? '  ·  In ${row.clockInDisplay}' : ''}'
                  '${row.clockOutDisplay != null ? '  ·  Out ${row.clockOutDisplay}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          iconSize: 28,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }
}

class _BigActionTile extends StatelessWidget {
  final AdminAction action;
  final VoidCallback? onTap;

  const _BigActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: action.color.withValues(alpha: disabled ? 0.05 : 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: action.color.withValues(alpha: disabled ? 0.2 : 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon,
                    size: 26,
                    color: disabled ? AppColors.textMuted : action.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: disabled ? AppColors.textMuted : action.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: disabled ? 0.2 : 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: disabled ? AppColors.textMuted : color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: disabled ? AppColors.textMuted : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
