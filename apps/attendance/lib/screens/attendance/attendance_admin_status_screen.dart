/// 관리자 모드 — Attendance status 변경 화면.
///
/// status 큰 버튼 선택 → 필요한 시각 보정 필드 노출 → 사유 필수 입력 → Save.
/// 서버는 변경된 필드를 attendance_corrections 에 기록.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_admin_provider.dart';
import '../../services/attendance_device_service.dart';
import 'attendance_admin_home_screen.dart' show extractApiError;

class AttendanceAdminStatusScreen extends ConsumerStatefulWidget {
  final AdminScheduleRow row;

  const AttendanceAdminStatusScreen({super.key, required this.row});

  @override
  ConsumerState<AttendanceAdminStatusScreen> createState() =>
      _AttendanceAdminStatusScreenState();
}

enum _StatusOption {
  working,
  onBreak,
  clockedOut,
  upcoming,
  noShow,
}

extension _StatusOptionX on _StatusOption {
  String get apiValue {
    switch (this) {
      case _StatusOption.working:
        return 'working';
      case _StatusOption.onBreak:
        return 'on_break';
      case _StatusOption.clockedOut:
        return 'clocked_out';
      case _StatusOption.upcoming:
        return 'upcoming';
      case _StatusOption.noShow:
        return 'no_show';
    }
  }

  String get label {
    switch (this) {
      case _StatusOption.working:
        return 'Working';
      case _StatusOption.onBreak:
        return 'On Break';
      case _StatusOption.clockedOut:
        return 'Clocked Out';
      case _StatusOption.upcoming:
        return 'Reset to Upcoming';
      case _StatusOption.noShow:
        return 'No Show';
    }
  }

  String get description {
    switch (this) {
      case _StatusOption.working:
        return 'Mark as currently working. Clock-in time can be adjusted.';
      case _StatusOption.onBreak:
        return 'Mark as on break. Clock-in time stays the same.';
      case _StatusOption.clockedOut:
        return 'Mark shift as completed. Clock-out time is required.';
      case _StatusOption.upcoming:
        return 'Clear clock-in/out and mark as not yet started.';
      case _StatusOption.noShow:
        return 'Mark as no-show. Clock-in/out will be cleared.';
    }
  }

  IconData get icon {
    switch (this) {
      case _StatusOption.working:
        return Icons.work_outline_rounded;
      case _StatusOption.onBreak:
        return Icons.coffee_rounded;
      case _StatusOption.clockedOut:
        return Icons.check_circle_outline_rounded;
      case _StatusOption.upcoming:
        return Icons.schedule_rounded;
      case _StatusOption.noShow:
        return Icons.cancel_outlined;
    }
  }

  Color get color {
    switch (this) {
      case _StatusOption.working:
        return AppColors.success;
      case _StatusOption.onBreak:
        return AppColors.warning;
      case _StatusOption.clockedOut:
        return AppColors.textSecondary;
      case _StatusOption.upcoming:
        return AppColors.accent;
      case _StatusOption.noShow:
        return AppColors.danger;
    }
  }

  bool get needsClockIn =>
      this == _StatusOption.working || this == _StatusOption.clockedOut;
  bool get needsClockOut => this == _StatusOption.clockedOut;
}

class _AttendanceAdminStatusScreenState
    extends ConsumerState<AttendanceAdminStatusScreen> {
  _StatusOption? _selected;
  TimeOfDay? _clockIn;
  TimeOfDay? _clockOut;
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 기존 시각을 picker initial 로 prefill
    _clockIn = _parseHHmm(widget.row.clockInDisplay);
    _clockOut = _parseHHmm(widget.row.clockOutDisplay);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseHHmm(String? s) {
    if (s == null || !s.contains(':')) return null;
    final parts = s.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isClockIn) async {
    final initial =
        (isClockIn ? _clockIn : _clockOut) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isClockIn) {
        _clockIn = picked;
      } else {
        _clockOut = picked;
      }
    });
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      AppModal.show(
        context,
        title: 'Pick a Status',
        message: 'Select the status to apply first.',
        type: ModalType.error,
      );
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      AppModal.show(
        context,
        title: 'Reason Required',
        message: 'Briefly describe why this status change is needed.',
        type: ModalType.error,
      );
      return;
    }
    if (selected.needsClockIn && _clockIn == null) {
      AppModal.show(
        context,
        title: 'Clock-in Required',
        message: 'Set the clock-in time for this status.',
        type: ModalType.error,
      );
      return;
    }
    if (selected.needsClockOut && _clockOut == null) {
      AppModal.show(
        context,
        title: 'Clock-out Required',
        message: 'Set the clock-out time for "Clocked Out".',
        type: ModalType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      await service.adminChangeStatus(
        userId: widget.row.userId,
        status: selected.apiValue,
        reason: _reasonCtrl.text.trim(),
        clockInHHmm: selected.needsClockIn && _clockIn != null
            ? _formatHHmm(_clockIn!)
            : null,
        clockOutHHmm: selected.needsClockOut && _clockOut != null
            ? _formatHHmm(_clockOut!)
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppModal.show(
        context,
        title: 'Could Not Change Status',
        message: extractApiError(e, 'Try again.'),
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Change Status'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _staffHeader(),
              const SizedBox(height: 24),
              const _SectionLabel('NEW STATUS'),
              const SizedBox(height: 10),
              ..._StatusOption.values.map(_statusTile),
              if (selected != null) ...[
                const SizedBox(height: 24),
                if (selected.needsClockIn || selected.needsClockOut) ...[
                  const _SectionLabel('TIMES'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (selected.needsClockIn)
                        Expanded(
                          child: _timeTile(
                            label: 'Clock In',
                            time: _clockIn,
                            onTap: () => _pickTime(true),
                          ),
                        ),
                      if (selected.needsClockIn && selected.needsClockOut)
                        const SizedBox(width: 12),
                      if (selected.needsClockOut)
                        Expanded(
                          child: _timeTile(
                            label: 'Clock Out',
                            time: _clockOut,
                            onTap: () => _pickTime(false),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                const _SectionLabel('REASON'),
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
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'Why is this change needed? (e.g. forgot to clock out)',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffHeader() {
    final row = widget.row;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.startHHmm ?? '--:--'} – ${row.endHHmm ?? '--:--'}  ·  '
                  'Current: ${(row.attendanceStatus ?? '—').toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTile(_StatusOption option) {
    final isSelected = _selected == option;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? option.color.withValues(alpha: 0.12) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selected = option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? option.color
                    : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: option.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.icon, color: option.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? option.color : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: option.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.access_time_rounded,
                  color: AppColors.textMuted),
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
