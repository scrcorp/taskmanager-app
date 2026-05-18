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

import '../../providers/attendance_admin_provider.dart';
import '../../services/attendance_device_service.dart';
import 'attendance_admin_home_screen.dart' show extractApiError;

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
}

class AttendanceAdminActionModal extends ConsumerStatefulWidget {
  final AdminAction action;
  final AdminScheduleRow row;

  const AttendanceAdminActionModal({
    super.key,
    required this.action,
    required this.row,
  });

  /// `Navigator.push` 헬퍼 — 성공 시 true 반환.
  static Future<bool> show(
    BuildContext context, {
    required AdminAction action,
    required AdminScheduleRow row,
  }) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AttendanceAdminActionModal(action: action, row: row),
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<AttendanceAdminActionModal> createState() =>
      _AttendanceAdminActionModalState();
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

class _AttendanceAdminActionModalState
    extends ConsumerState<AttendanceAdminActionModal> {
  TimeOfDay? _time;
  /// preset 선택 (null = 미선택 / "Other" = 직접 입력).
  String? _reasonPreset;
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.action.needsTime) {
      _time = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _formatHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  /// 최종 reason — preset 선택했으면 그 라벨, Other 면 free-text, 아니면 "".
  /// 빈 문자열이면 서버가 "(no reason)" 으로 기록.
  String get _effectiveReason {
    if (_reasonPreset == null) return _reasonCtrl.text.trim();
    if (_reasonPreset == 'Other') return _reasonCtrl.text.trim();
    return _reasonPreset!;
  }

  Future<void> _apply() async {
    if (_saving) return;
    // reason 은 선택 — preset 또는 Other 의 free-text, 둘 다 안 채우면 "".
    final reason = _effectiveReason;
    if (widget.action.needsTime && _time == null) {
      AppModal.show(
        context,
        title: 'Time Required',
        message: 'Set the ${widget.action.timeLabel} time.',
        type: ModalType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      switch (widget.action) {
        case AdminAction.clockIn:
          await service.adminChangeStatus(
            userId: widget.row.userId,
            status: 'working',
            reason: reason,
            clockInHHmm: _formatHHmm(_time!),
          );
          break;
        case AdminAction.clockOut:
          await service.adminChangeStatus(
            userId: widget.row.userId,
            status: 'clocked_out',
            reason: reason,
            // 기존 clock_in 유지 (서버가 알아서 처리). clock_out 만 갱신.
            clockInHHmm: widget.row.clockInDisplay,
            clockOutHHmm: _formatHHmm(_time!),
          );
          break;
        case AdminAction.break10min:
          await service.adminClockAction(
            userId: widget.row.userId,
            action: 'break_start',
            breakType: 'paid_10min',
            reason: reason,
          );
          break;
        case AdminAction.breakMeal:
          await service.adminClockAction(
            userId: widget.row.userId,
            action: 'break_start',
            breakType: 'unpaid_meal',
            reason: reason,
          );
          break;
        case AdminAction.endBreak:
          await service.adminClockAction(
            userId: widget.row.userId,
            action: 'break_end',
            reason: reason,
          );
          break;
        case AdminAction.undoClockIn:
          await service.adminClockAction(
            userId: widget.row.userId,
            action: 'cancel_clock_in',
            reason: reason,
          );
          break;
        case AdminAction.reopenShift:
          await service.adminClockAction(
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(action.title),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 26),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Action header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: action.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(action.icon, size: 28, color: action.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: action.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                action.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (action.needsTime) ...[
                const _SectionLabel('TIME'),
                const SizedBox(height: 10),
                _timeTile(action.timeLabel, _time, _pickTime),
                const SizedBox(height: 24),
              ],
              const _SectionLabel('REASON (OPTIONAL)'),
              const SizedBox(height: 6),
              const Text(
                'Tap a preset, pick Other to type, or skip and add later from the Console.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
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
                    maxLines: 3,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Describe the reason',
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: _saving ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action.color,
                    disabledBackgroundColor:
                        action.color.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Confirm ${action.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay? time, VoidCallback onTap) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time != null ? _formatHHmm(time) : '--:--',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.access_time_rounded,
                  color: AppColors.textMuted, size: 28),
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
