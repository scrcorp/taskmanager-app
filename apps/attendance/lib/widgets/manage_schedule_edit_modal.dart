/// Manage 스케줄 추가/수정 중앙 모달 (Issue 10 Step 5).
///
/// STAFF(필수) / WORK ROLE(선택, 선택 시 기본 시간) / Start·End(휠 피커).
/// New: Start=현재(5분 반올림), End=Start+5.5h. work role 선택 시 사용자가 안 건드린 필드만 덮음.
/// 충돌은 Console 에서 처리 (안내 노트).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../providers/attendance_manage_provider.dart';
import '../services/attendance_device_service.dart';
import '../screens/attendance/attendance_manage_home_screen.dart' show extractApiError;
import '../utils/schedule_edit_logic.dart';
import 'time_wheel.dart';

class ManageScheduleEditModal extends ConsumerStatefulWidget {
  final AdminScheduleRow? existing;
  const ManageScheduleEditModal({super.key, this.existing});

  /// showDialog 헬퍼 — 저장 성공 시 true.
  static Future<bool> show(BuildContext context, {AdminScheduleRow? existing}) async {
    final r = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ManageScheduleEditModal(existing: existing),
    );
    return r == true;
  }

  @override
  ConsumerState<ManageScheduleEditModal> createState() => _ManageScheduleEditModalState();
}

class _ManageScheduleEditModalState extends ConsumerState<ManageScheduleEditModal> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<AdminAssignableUser> _users = const [];
  List<AdminWorkRole> _workRoles = const [];

  String? _userId;
  String? _workRoleId;
  int? _startMin;
  int? _endMin;
  bool _startTouched = false;
  bool _endTouched = false;
  int _startKey = 0;
  int _endKey = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _userId = e.userId;
      _workRoleId = e.workRoleId;
      _startMin = hhmmToMinutes(e.startHHmm);
      _endMin = hhmmToMinutes(e.endHHmm);
      _startTouched = true;
      _endTouched = true;
    } else {
      final now = DateTime.now();
      _startMin = round5ToNow(now);
      _endMin = clampMinutes(_startMin! + defaultShiftMinutes);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final res = await Future.wait([service.manageListAssignableUsers(), service.manageListWorkRoles()]);
      if (!mounted) return;
      setState(() {
        _users = res[0].map(AdminAssignableUser.fromJson).toList();
        _workRoles = res[1].map(AdminWorkRole.fromJson).toList();
        // prefill 된 work role 이 목록에 없으면(삭제 등) 드롭다운 assert 방지 위해 해제
        if (_workRoleId != null && !_workRoles.any((r) => r.workRoleId == _workRoleId)) {
          _workRoleId = null;
        }
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

  void _pickWorkRole(String? id) {
    setState(() {
      _workRoleId = id;
      if (id == null) return;
      final role = _workRoles.firstWhere((r) => r.workRoleId == id,
          orElse: () => const AdminWorkRole(
              workRoleId: '', name: null, shiftName: null, positionName: null, defaultStartHHmm: null, defaultEndHHmm: null));
      if (!_startTouched) {
        final s = hhmmToMinutes(role.defaultStartHHmm);
        if (s != null) {
          _startMin = s;
          _startKey++;
        }
      }
      if (!_endTouched) {
        final en = hhmmToMinutes(role.defaultEndHHmm);
        if (en != null) {
          _endMin = en;
          _endKey++;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_userId == null || _startMin == null || _endMin == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      // 주의: 키오스크는 영업일 경계(day_start_time) 로직이 없어 business date를 로컬로
      // 신뢰성 있게 계산할 수 없다. 서버가 get_work_date로 today를 정확히 판정하고
      // start_at/end_at을 assemble하므로 여기선 HHmm만 보낸다(날짜 날조 방지).
      // device service는 datetime 인코딩 파라미터를 수용하나(forward-compat), 앱이
      // 경계 로직을 갖추기 전엔 전달하지 않는다.
      if (_isEdit) {
        await service.manageUpdateSchedule(
          scheduleId: widget.existing!.scheduleId,
          userId: _userId,
          workRoleId: _workRoleId,
          startHHmm: minutesToHHmm(_startMin!),
          endHHmm: minutesToHHmm(_endMin!),
        );
      } else {
        await service.manageCreateSchedule(
          userId: _userId!,
          workRoleId: _workRoleId,
          startHHmm: minutesToHHmm(_startMin!),
          endHHmm: minutesToHHmm(_endMin!),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      String msg = extractApiError(e, 'Could not save schedule.');
      final low = msg.toLowerCase();
      if (low.contains('overlap') || low.contains('conflict') || low.contains('already')) {
        msg = 'This staff already has a conflicting schedule. Resolve the overlap from the Console.\n\n$msg';
      }
      AppModal.show(context, title: 'Save Failed', message: msg, type: ModalType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _userId != null && _startMin != null && _endMin != null && !_loading;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(_isEdit ? 'Edit Schedule' : 'New Schedule',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('STAFF', required: true),
                        _dropdown<String>(
                          value: _userId,
                          hint: 'Select staff',
                          items: _users
                              .map((u) => DropdownMenuItem(value: u.userId, child: Text('${u.fullName}  ·  ${u.roleName}')))
                              .toList(),
                          onChanged: (v) => setState(() => _userId = v),
                        ),
                        _label('WORK ROLE (OPTIONAL)'),
                        _dropdown<String?>(
                          value: _workRoleId,
                          hint: 'No specific role',
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('— None')),
                            ..._workRoles.map((r) => DropdownMenuItem<String?>(value: r.workRoleId, child: Text(r.displayLabel))),
                          ],
                          onChanged: _pickWorkRole,
                        ),
                        _label('TIME', required: true),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _wheelTile('Start', _startMin, _startKey, true)),
                            const SizedBox(width: 12),
                            Expanded(child: _wheelTile('End', _endMin, _endKey, false)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Kiosk handles today's simple edits. If this overlaps another schedule, resolve it from the Console.",
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                        ),
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
                      onPressed: (canSave && !_saving) ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEdit ? 'Save Changes' : 'Create Schedule',
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

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Text(text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
          if (required) const Text(' *', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppColors.textMuted)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _wheelTile(String label, int? min, int keyEpoch, bool isStart) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
          TimeWheel(
            key: ValueKey('${isStart ? 'start' : 'end'}-$keyEpoch'),
            initialMinutes: min ?? 0,
            onChanged: (v) => setState(() {
              if (isStart) {
                _startMin = v;
                _startTouched = true;
                if (!_endTouched) {
                  _endMin = clampMinutes(v + defaultShiftMinutes);
                  _endKey++;
                }
              } else {
                _endMin = v;
                _endTouched = true;
              }
            }),
          ),
        ],
      ),
    );
  }
}
