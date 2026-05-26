/// 관리자 모드 — 오늘 스케줄 추가/수정 화면.
///
/// 직원 + work role + 시작/종료 시간 선택.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';

class AttendanceManageScheduleEditScreen extends ConsumerStatefulWidget {
  /// null 이면 새 스케줄 생성, 아니면 기존 스케줄 수정.
  final AdminScheduleRow? existing;

  const AttendanceManageScheduleEditScreen({super.key, this.existing});

  @override
  ConsumerState<AttendanceManageScheduleEditScreen> createState() =>
      _AttendanceManageScheduleEditScreenState();
}

class _AttendanceManageScheduleEditScreenState
    extends ConsumerState<AttendanceManageScheduleEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<AdminAssignableUser> _users = const [];
  List<AdminWorkRole> _workRoles = const [];

  String? _selectedUserId;
  String? _selectedWorkRoleId;
  TimeOfDay? _start;
  TimeOfDay? _end;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _selectedUserId = e.userId;
      _selectedWorkRoleId = e.workRoleId;
      _start = _parseHHmm(e.startHHmm);
      _end = _parseHHmm(e.endHHmm);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
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

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final results = await Future.wait([
        service.manageListAssignableUsers(),
        service.manageListWorkRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0].map(AdminAssignableUser.fromJson).toList();
        _workRoles = results[1].map(AdminWorkRole.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load options.';
        _loading = false;
      });
    }
  }

  void _applyWorkRoleDefaults(AdminWorkRole role) {
    // 새 스케줄 + 시간 미설정 시에만 기본값 적용 (사용자가 이미 정한 시간을 덮어쓰지 않음)
    if (_isEdit) return;
    if (_start == null) _start = _parseHHmm(role.defaultStartHHmm);
    if (_end == null) _end = _parseHHmm(role.defaultEndHHmm);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end ?? (_start ?? TimeOfDay.now()),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_selectedUserId == null) {
      AppModal.show(
        context,
        title: 'Missing Staff',
        message: 'Please select a staff member.',
        type: ModalType.error,
      );
      return;
    }
    if (_start == null || _end == null) {
      AppModal.show(
        context,
        title: 'Missing Time',
        message: 'Please select start and end time.',
        type: ModalType.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      if (_isEdit) {
        await service.manageUpdateSchedule(
          scheduleId: widget.existing!.scheduleId,
          userId: _selectedUserId,
          workRoleId: _selectedWorkRoleId,
          startHHmm: _formatHHmm(_start!),
          endHHmm: _formatHHmm(_end!),
        );
      } else {
        await service.manageCreateSchedule(
          userId: _selectedUserId!,
          workRoleId: _selectedWorkRoleId,
          startHHmm: _formatHHmm(_start!),
          endHHmm: _formatHHmm(_end!),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      String message = 'Could not save schedule.';
      String title = 'Save Failed';
      try {
        final resp = (e as dynamic).response;
        final data = resp?.data;
        if (data is Map && data['detail'] is String) {
          message = data['detail'] as String;
        }
      } catch (_) {}
      // 직원 변경 시 다른 스케줄과 충돌 → 콘솔에서 처리하라고 안내.
      // 서버는 "Validation failed: ..." 형태로 반환.
      final isConflict = message.toLowerCase().contains('overlap') ||
          message.toLowerCase().contains('conflict') ||
          message.toLowerCase().contains('already');
      if (isConflict) {
        title = 'Schedule Conflict';
        message =
            'This staff already has a schedule that conflicts with today\'s shift. '
            'Please resolve the overlap from the Console — kiosk only handles today\'s simple edits.\n\n'
            'Server detail: $message';
      }
      AppModal.show(
        context,
        title: title,
        message: message,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Schedule' : 'New Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadOptions, child: const Text('Retry')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionLabel('STAFF'),
        const SizedBox(height: 8),
        _userDropdown(),
        const SizedBox(height: 20),
        _sectionLabel('WORK ROLE (OPTIONAL)'),
        const SizedBox(height: 8),
        _workRoleDropdown(),
        const SizedBox(height: 20),
        _sectionLabel('TIME'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _timeTile('Start', _start, _pickStart)),
            const SizedBox(width: 12),
            Expanded(child: _timeTile('End', _end, _pickEnd)),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );

  Widget _userDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedUserId,
          hint: const Text('Select staff'),
          items: _users
              .map(
                (u) => DropdownMenuItem<String>(
                  value: u.userId,
                  child: Text('${u.fullName}  ·  ${u.roleName}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedUserId = v),
        ),
      ),
    );
  }

  Widget _workRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedWorkRoleId,
          hint: const Text('No specific role'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('— None'),
            ),
            ..._workRoles.map(
              (r) => DropdownMenuItem<String?>(
                value: r.workRoleId,
                child: Text(r.displayLabel),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _selectedWorkRoleId = v);
            if (v != null) {
              final role = _workRoles.firstWhere(
                (r) => r.workRoleId == v,
                orElse: () => const AdminWorkRole(
                  workRoleId: '',
                  name: null,
                  shiftName: null,
                  positionName: null,
                  defaultStartHHmm: null,
                  defaultEndHHmm: null,
                ),
              );
              _applyWorkRoleDefaults(role);
            }
          },
        ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay? time, VoidCallback onTap) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
