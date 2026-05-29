/// 관리자 모드 — 개별 attendance 액션 확인/적용 모달.
///
/// Action Sheet 에서 "Clock In / Clock Out / Break / End Break / Undo / Reopen"
/// 를 탭하면 이 모달이 열려서 (필요한 경우) 시각 picker 와 사유 textfield 를 받고
/// 적절한 서버 API 를 호출한다. 호출 분기:
///   - Clock In/Out:  /admin/attendance/status (status_change)
///   - Break / End / Undo / Reopen: /admin/clock
/// 두 API 모두 attendance_corrections 에 reason 으로 기록 → console 의 Correction
/// History 에 잡힌다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import '../../utils/staff_status_utils.dart' show breakProgress, BreakState;
import '../../widgets/time_wheel.dart';
import 'attendance_manage_home_screen.dart' show extractApiError;

enum AdminAction {
  clockIn,
  clockOut,
  break10min,
  breakMeal,
  endBreak,
  undoClockIn,
  reopenShift,
}

extension AdminActionX on AdminAction {
  String get title {
    switch (this) {
      case AdminAction.clockIn:
        return 'Clock In';
      case AdminAction.clockOut:
        return 'Clock Out';
      case AdminAction.break10min:
        return 'Start 10-min Break';
      case AdminAction.breakMeal:
        return 'Start Meal Break';
      case AdminAction.endBreak:
        return 'End Break';
      case AdminAction.undoClockIn:
        return 'Undo Clock-in';
      case AdminAction.reopenShift:
        return 'Undo Clock-out';
    }
  }

  String get description {
    switch (this) {
      case AdminAction.clockIn:
        return 'Mark this staff as clocked in. Set the actual start time if different from now.';
      case AdminAction.clockOut:
        return 'End the shift. Set the actual end time if different from now.';
      case AdminAction.break10min:
        return 'Start a paid 10-minute break for this staff.';
      case AdminAction.breakMeal:
        return 'Start an unpaid meal break for this staff.';
      case AdminAction.endBreak:
        return 'End the current break and resume work.';
      case AdminAction.undoClockIn:
        return 'Clear clock-in time. The shift becomes upcoming again.';
      case AdminAction.reopenShift:
        return 'Undo the clock-out. Clock-out time is cleared and the staff returns to working status.';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminAction.clockIn:
        return Icons.login_rounded;
      case AdminAction.clockOut:
        return Icons.logout_rounded;
      case AdminAction.break10min:
        return Icons.coffee_rounded;
      case AdminAction.breakMeal:
        return Icons.restaurant_rounded;
      case AdminAction.endBreak:
        return Icons.play_circle_outline_rounded;
      case AdminAction.undoClockIn:
        return Icons.undo_rounded;
      case AdminAction.reopenShift:
        return Icons.undo_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AdminAction.clockIn:
        return AppColors.success;
      case AdminAction.clockOut:
        return AppColors.textSecondary;
      case AdminAction.break10min:
      case AdminAction.breakMeal:
        return AppColors.warning;
      case AdminAction.endBreak:
        return AppColors.success;
      case AdminAction.undoClockIn:
        return AppColors.danger;
      case AdminAction.reopenShift:
        return AppColors.accent;
    }
  }

  bool get needsTime =>
      this == AdminAction.clockIn || this == AdminAction.clockOut;
  String get timeLabel =>
      this == AdminAction.clockIn ? 'Clock In' : 'Clock Out';

  /// 데이터 클리어/되돌림 액션 — 사유 필수.
  bool get reasonRequired =>
      this == AdminAction.undoClockIn || this == AdminAction.reopenShift;
}

/// state(upcoming/working/breaking/done) → 가능한 clock 액션 (anomaly/soon 무관).
List<AdminAction> adminActionsForState(String state) {
  switch (state) {
    case 'working':
      return const [
        AdminAction.clockOut,
        AdminAction.break10min,
        AdminAction.breakMeal,
        AdminAction.undoClockIn,
      ];
    case 'breaking':
      return const [AdminAction.endBreak, AdminAction.clockOut, AdminAction.undoClockIn];
    case 'done':
      return const [AdminAction.reopenShift];
    case 'upcoming':
    default:
      return const [AdminAction.clockIn];
  }
}

class AttendanceManageActionModal extends ConsumerStatefulWidget {
  final AdminAction action;
  final AdminScheduleRow row;

  const AttendanceManageActionModal({
    super.key,
    required this.action,
    required this.row,
  });

  /// 중앙 모달 헬퍼 — 적용 성공 시 true 반환.
  static Future<bool> show(
    BuildContext context, {
    required AdminAction action,
    required AdminScheduleRow row,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => AttendanceManageActionModal(action: action, row: row),
    );
    return result == true;
  }

  @override
  ConsumerState<AttendanceManageActionModal> createState() =>
      _AttendanceManageActionModalState();
}

/// Console 의 correctionPresets.ts 와 동일한 preset 목록. 양쪽 history 일관성용.
const _kReasonPresets = <String>[
  'Forgot to clock in',
  'Forgot to clock out',
  'Wrong time recorded',
  'Device / network issue',
  'Schedule change',
  'Break correction',
];

class _AttendanceManageActionModalState
    extends ConsumerState<AttendanceManageActionModal> {
  int _minutes = 0; // needsTime 일 때 hh*60+mm
  late final int _nowMinutes;
  /// preset 선택 (null = 미선택 / "Other" = 직접 입력).
  String? _reasonPreset;
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _nowMinutes = now.hour * 60 + now.minute;
    _minutes = _nowMinutes;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _formatHHmm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  /// End Break 정책 (진행 중 break 의 경과/초과) — endBreak 일 때만.
  ({String hint, bool over})? get _breakPolicy {
    if (widget.action != AdminAction.endBreak) return null;
    final active = widget.row.breaks.where((b) => b.end == null).toList();
    if (active.isEmpty) return null;
    final b = active.first;
    final parts = b.start.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (h == null || m == null) return null;
    final elapsed = (_nowMinutes - (h * 60 + m)).clamp(0, 24 * 60);
    final p = breakProgress(b.type, elapsed);
    final over = p.state != BreakState.within && p.state != BreakState.tooShort;
    return (hint: p.hint, over: over);
  }

  bool get _reasonRequired =>
      widget.action.reasonRequired || (_breakPolicy?.over ?? false);

  /// 최종 reason — preset 선택했으면 그 라벨, Other 면 free-text, 아니면 "".
  String get _effectiveReason {
    if (_reasonPreset == null) return _reasonCtrl.text.trim();
    if (_reasonPreset == 'Other') return _reasonCtrl.text.trim();
    return _reasonPreset!;
  }

  Future<void> _apply() async {
    if (_saving) return;
    final reason = _effectiveReason;
    if (_reasonRequired && reason.isEmpty) {
      AppModal.show(
        context,
        title: 'Reason Required',
        message: 'A reason is required for this action.',
        type: ModalType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      switch (widget.action) {
        case AdminAction.clockIn:
          await service.manageChangeStatus(
            userId: widget.row.userId,
            status: 'working',
            reason: reason,
            clockInHHmm: _formatHHmm(_minutes),
          );
          break;
        case AdminAction.clockOut:
          await service.manageChangeStatus(
            userId: widget.row.userId,
            status: 'clocked_out',
            reason: reason,
            // 기존 clock_in 유지 (서버가 알아서 처리). clock_out 만 갱신.
            clockInHHmm: widget.row.clockInDisplay,
            clockOutHHmm: _formatHHmm(_minutes),
          );
          break;
        case AdminAction.break10min:
          await service.manageClockAction(
            userId: widget.row.userId,
            action: 'break_start',
            breakType: 'paid_10min',
            reason: reason,
          );
          break;
        case AdminAction.breakMeal:
          await service.manageClockAction(
            userId: widget.row.userId,
            action: 'break_start',
            breakType: 'unpaid_meal',
            reason: reason,
          );
          break;
        case AdminAction.endBreak:
          await service.manageClockAction(
            userId: widget.row.userId,
            action: 'break_end',
            reason: reason,
          );
          break;
        case AdminAction.undoClockIn:
          await service.manageClockAction(
            userId: widget.row.userId,
            action: 'cancel_clock_in',
            reason: reason,
          );
          break;
        case AdminAction.reopenShift:
          await service.manageClockAction(
            userId: widget.row.userId,
            action: 'cancel_clock_out',
            reason: reason,
          );
          break;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppModal.show(
        context,
        title: 'Action Failed',
        message: extractApiError(e, 'Could not apply action.'),
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final row = widget.row;
    final policy = _breakPolicy;
    final required = _reasonRequired;
    final canApply = !required || _effectiveReason.isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.userName.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(action.title,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: action.color)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(action.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              if (action.needsTime) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      _SectionLabel('${action.timeLabel.toUpperCase()} TIME'),
                      TimeWheel(initialMinutes: _minutes, onChanged: (v) => setState(() => _minutes = v)),
                      if (_minutes != _nowMinutes)
                        Text(
                          () {
                            final d = (_minutes - _nowMinutes).abs();
                            final lbl = d >= 60 ? '${d ~/ 60}h ${d % 60}m' : '${d}m';
                            return '$lbl ${_minutes < _nowMinutes ? 'earlier' : 'later'} than now';
                          }(),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
              if (policy != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (policy.over ? AppColors.danger : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(policy.hint,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: policy.over ? AppColors.danger : AppColors.warning)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _SectionLabel('REASON'),
                  const Spacer(),
                  Text(required ? 'Required' : 'Optional',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: required ? AppColors.danger : AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _kReasonPresets)
                            _ReasonChip(
                              label: p,
                              selected: _reasonPreset == p,
                              onTap: () => setState(() {
                                _reasonPreset = _reasonPreset == p ? null : p;
                                if (_reasonPreset != 'Other') _reasonCtrl.clear();
                              }),
                            ),
                          _ReasonChip(
                            label: 'Other',
                            selected: _reasonPreset == 'Other',
                            onTap: () => setState(() {
                              _reasonPreset = _reasonPreset == 'Other' ? null : 'Other';
                            }),
                          ),
                        ],
                      ),
                      if (_reasonPreset == 'Other') ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _reasonCtrl,
                            maxLines: 2,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Describe the reason'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_saving || !canApply) ? null : _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action.color,
                        disabledBackgroundColor: action.color.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(action.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );
}

class _ReasonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.15)
          : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accent : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
