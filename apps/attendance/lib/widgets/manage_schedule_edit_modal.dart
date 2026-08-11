/// Manage 스케줄 추가/수정 중앙 모달.
///
/// STAFF(필수) / WORK ROLE(선택) / **Start · End · Length 3필드**(D5-2).
/// 시각 표기는 벽시계 + `+1` 마커 (`02:00 +1`) — 24 초과 표기는 쓰지 않는다(D5-1).
///
/// 저장은 **항상 전체 전송**이다(D7-3). 서버가 "기존 값과 달라진 필드"만 검사하므로
/// 부분 전송이 필요 없고, 오히려 한쪽만 보내면 영업일 번역이 스킵돼 새벽조 날짜가
/// 틀어진다. 예전의 `_startEdited`/`_endEdited`/`_endTouched` 플래그는 전부 없앴다 —
/// 같은 조작에 다른 결과가 나오던 원인이었다.
///
/// 경고는 삼키지 않는다: 409 `SCHEDULE_WARNINGS_UNCONFIRMED` 를 받으면 무엇이
/// 걸렸는지 보여주고, 매니저가 확인한 경우에만 `force: true` 로 재요청한다(D9-1).
///
/// **BREAK 행**(F6): 휴게는 근무 시작 기준 오프셋으로 들고 있어서 시작을 옮기면
/// 함께 움직인다(B2). 원치 않으면 지우고 다시 넣는다(B4) — 그래서 지우기 수단이
/// 필수다. 예전엔 휴게 UI 자체가 없어서, 근무를 줄여 휴게가 밖으로 밀려나면
/// 저장은 거부되는데 사용자가 그걸 해소할 방법이 없었다(데드락).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../providers/attendance_device_provider.dart';
import '../providers/attendance_manage_provider.dart';
import '../services/attendance_device_service.dart';
import '../screens/attendance/attendance_manage_home_screen.dart' show extractApiError;
import '../utils/roster_day.dart';
import '../utils/schedule_codes.dart';
import '../utils/schedule_edit_logic.dart';
import '../utils/store_time.dart';
import 'time_wheel.dart';

class ManageScheduleEditModal extends ConsumerStatefulWidget {
  final AdminScheduleRow? existing;

  /// 신규 생성 대상 영업일. null 이면 기기가 보는 오늘.
  ///
  /// 매니저가 다른 영업일을 보고 있을 때 "Add Schedule" 을 누르면 **그 날**에
  /// 만들어져야 한다. 안 넘기면 서버가 오늘로 앵커해서, 화면엔 어제를 띄워놓고
  /// 오늘 스케줄을 만드는 사고가 난다(F5).
  final DateTime? operatingDay;

  const ManageScheduleEditModal({super.key, this.existing, this.operatingDay});

  /// showDialog 헬퍼 — 저장 성공 시 true.
  static Future<bool> show(
    BuildContext context, {
    AdminScheduleRow? existing,
    DateTime? operatingDay,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => ManageScheduleEditModal(
        existing: existing,
        operatingDay: operatingDay,
      ),
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

  /// 시각 상태는 이것 하나뿐 — (시작, 길이). 종료는 파생값이라 따로 들고 있지 않는다.
  late ShiftTimes _times;

  // 휠은 initialMinutes 를 initState 에서만 읽는다. 값을 코드로 바꿨을 때
  // (역할 기본시간, 종료 변경에 따른 재계산) 다시 만들기 위한 key epoch.
  int _startKey = 0;
  int _endKey = 0;
  int _breakStartKey = 0;
  int _breakEndKey = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _userId = e.userId;
      _workRoleId = e.workRoleId;
      // 기존 값은 그대로 둔다. 워크인 스케줄은 실제 clock-in 시각(5분 배수가 아님)이라
      // 여는 것만으로 값이 바뀌면 근태 기록이 왜곡된다. 서버는 "달라진 값"만 검사하므로
      // 안 건드린 비배수 값을 그대로 되보내도 안전하다(D7-2).
      //
      // start_at/end_at 이 있으면 그쪽이 정본이다 — 날짜가 붙어 있어 자정 넘김과
      // 24시간 이상 근무의 길이가 정확하다. HH:mm 두 개로는 그것을 표현할 수 없다.
      final sAt = e.startAt, eAt = e.endAt;
      if (sAt != null && eAt != null) {
        _times = ShiftTimes.fromInstants(
          sAt,
          eAt,
          breakWindow: breakWindowFrom(
            shiftStartAt: sAt,
            breakStartAt: e.breakStartAt,
            breakEndAt: e.breakEndAt,
            shiftStartMinutes: wrapMinutes(sAt.hour * 60 + sAt.minute),
            breakStartMinutes: hhmmToMinutes(e.breakStartHHmm),
            breakEndMinutes: hhmmToMinutes(e.breakEndHHmm),
          ),
        );
      } else {
        final s = hhmmToMinutes(e.startHHmm) ?? 0;
        _times = ShiftTimes.fromStartEnd(
          s,
          hhmmToMinutes(e.endHHmm) ?? 0,
          breakWindow: breakWindowFrom(
            shiftStartMinutes: s,
            breakStartMinutes: hhmmToMinutes(e.breakStartHHmm),
            breakEndMinutes: hhmmToMinutes(e.breakEndHHmm),
          ),
        );
      }
    } else {
      // 신규 기본값: 시작 = 지금(5분 반올림), 길이 = 설정 기본(D8-1/D8-4).
      // 키오스크는 "지금 이 사람"을 다루는 도구라 현재 시각 기준이 맞다.
      _times = ShiftTimes(startMinutes: round5ToNow(_storeNow()), durationMinutes: _defaultShiftMinutes());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// 매장 벽시계 기준 현재 시각. 기기 위치가 매장과 달라도 매장 시간으로 만든다.
  DateTime _storeNow() {
    final device = ref.read(attendanceDeviceProvider).device;
    return toStoreClock(DateTime.now().toUtc(), device?.storeTimezoneOffsetMinutes);
  }

  /// 신규 스케줄 기본 길이 — 매장 설정값(D8-2).
  ///
  /// 서버가 `GET /attendance/me` 로 내려준 `default_schedule_duration_minutes` 를
  /// 쓴다. 아직 기기 정보를 못 받은 순간을 위해서만 폴백을 남긴다
  /// ([fallbackShiftMinutes] 주석 참조).
  int _defaultShiftMinutes() =>
      ref.read(attendanceDeviceProvider).device?.defaultScheduleDurationMinutes ??
      fallbackShiftMinutes;

  /// 이 스케줄이 속한 영업일. 수정이면 행의 라벨, 신규면 호출부가 지정한 날
  /// (지정 없으면 기기가 보고 있는 오늘).
  DateTime? get _operatingDay {
    final existing = widget.existing?.operatingDay;
    if (existing != null) return existing;
    if (widget.operatingDay != null) return widget.operatingDay;
    final raw = ref.read(attendanceDeviceProvider).device?.workDate;
    return raw == null ? null : DateTime.tryParse(raw);
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

  /// 역할 선택은 **항상** 그 역할의 기본 시간을 적용한다.
  ///
  /// 예전엔 "사용자가 아직 안 건드린 필드만" 덮었는데, 그 숨은 조건 때문에 같은
  /// 역할을 골라도 결과가 달랐다. 역할 선택은 명시적 조작이므로 결과도 하나여야 한다.
  /// 되돌리고 싶으면 휠로 다시 맞추면 된다(되돌릴 수 있는 조작이다).
  void _pickWorkRole(String? id) {
    setState(() {
      _workRoleId = id;
      if (id == null) return;
      final role = _workRoles.firstWhere(
        (r) => r.workRoleId == id,
        orElse: () => const AdminWorkRole(
            workRoleId: '', name: null, shiftName: null, positionName: null,
            defaultStartHHmm: null, defaultEndHHmm: null),
      );
      // 역할 기본시간은 console 에서 임의 분으로 저장될 수 있어 step 스냅 후 반영.
      final s = hhmmToMinutes(role.defaultStartHHmm);
      final en = hhmmToMinutes(role.defaultEndHHmm);
      if (s == null && en == null) return;
      var next = _times;
      if (s != null) next = next.withStart(snapToStep(s));
      if (en != null) next = next.withEnd(snapToStep(en));
      _times = next;
      _startKey++;
      _endKey++;
    });
  }

  void _setStart(int minutes) {
    setState(() {
      _times = _times.withStart(minutes);
      _endKey++; // 종료가 따라 움직였다 — 휠 표시를 갱신
      // 휴게도 같은 오프셋으로 따라 움직인다(B2). 휠은 initialMinutes 를 다시 읽지
      // 않으므로 key 를 올려 새로 만들어야 화면과 상태가 어긋나지 않는다.
      _breakStartKey++;
      _breakEndKey++;
    });
  }

  void _setBreakStart(int minutes) {
    setState(() {
      _times = _times.withBreakStart(minutes);
      _breakEndKey++; // 휴게 종료가 따라 움직였다
    });
  }

  void _setBreakEnd(int minutes) {
    setState(() => _times = _times.withBreakEnd(minutes));
  }

  void _addBreak() {
    setState(() {
      _times = _times.withDefaultBreak();
      _breakStartKey++;
      _breakEndKey++;
    });
  }

  /// 휴게 삭제. 저장 시 서버에 `null` 두 개로 나가 실제로 지워진다(B7).
  /// "동반 이동이 싫으면 지우고 다시 넣는다"(B4)의 지우기 쪽이다.
  void _removeBreak() {
    setState(() => _times = _times.withoutBreak());
  }

  void _setEnd(int minutes) {
    setState(() => _times = _times.withEnd(minutes));
  }

  void _bumpDuration(int deltaMinutes) {
    final next = _times.durationMinutes + deltaMinutes;
    // 길이는 0 이하로 못 내려간다 — 0분 근무는 서버가 막는 에러다(ZERO_DURATION).
    if (next < scheduleStepMinutes) return;
    setState(() {
      _times = _times.withDuration(next);
      _endKey++;
    });
  }

  Future<void> _save({bool force = false}) async {
    if (_saving) return;
    if (_userId == null || !_times.canSave) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      // 주의: 키오스크는 영업일 경계(day_start_time) 로직이 없어 달력 날짜를 로컬에서
      // 신뢰성 있게 계산할 수 없다. 서버가 경계 기준으로 start_at/end_at 을 조립하므로
      // 여기선 HH:mm 만 보낸다 (날짜 날조 방지). 자정 넘김은 종료 ≤ 시작이라는
      // 사실만으로 서버가 다음 날로 앵커한다.
      final start = minutesToHHmm(_times.startMinutes);
      final end = minutesToHHmm(_times.endMinutes);
      // 휴게도 HH:mm 만 보낸다 — 서버가 **근무 시작에 앵커**해 날짜를 붙이므로
      // 자정 넘긴 근무의 01:00 휴게도 자동으로 다음 달력일이 된다.
      // 휴게가 없으면 null 두 개 = 삭제(B7). 신 클라이언트는 항상 전체 전송이라
      // "생략"이라는 상태가 없다(D7-3).
      final bs = _times.breakStartMinutes;
      final be = _times.breakEndMinutes;
      final breakStart = bs == null ? null : minutesToHHmm(bs);
      final breakEnd = be == null ? null : minutesToHHmm(be);
      if (_isEdit) {
        await service.manageUpdateSchedule(
          scheduleId: widget.existing!.scheduleId,
          userId: _userId,
          workRoleId: _workRoleId,
          startHHmm: start,
          endHHmm: end,
          breakStartHHmm: breakStart,
          breakEndHHmm: breakEnd,
          force: force,
        );
      } else {
        await service.manageCreateSchedule(
          userId: _userId!,
          workRoleId: _workRoleId,
          startHHmm: start,
          endHHmm: end,
          breakStartHHmm: breakStart,
          breakEndHHmm: breakEnd,
          // 오늘이 아닌 영업일을 보고 있으면 그 날짜로 만든다. 안 보내면 서버가
          // 오늘로 앵커한다.
          operatingDay: widget.operatingDay == null
              ? null
              : operatingDayParam(widget.operatingDay!),
          force: force,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _handleSaveError(e);
    }
  }

  /// 저장 실패 처리 — 분기는 **최상위 code 로만** 한다.
  ///
  /// 메시지 문자열을 매칭하면 서버 문구가 바뀌는 순간 조용히 깨진다. 또 409 는
  /// 급여 잠금·폐점·PIN 충돌도 쓰기 때문에, status 만 보고 "Save anyway" 를 띄우면
  /// 넘길 수 없는 것을 넘길 수 있는 것처럼 보여주게 된다.
  Future<void> _handleSaveError(Object e) async {
    final failure = parseScheduleFailure(e);
    if (failure != null && failure.isUnconfirmedWarnings && failure.warnings.isNotEmpty) {
      final ok = await AppModal.show(
        context,
        title: 'Save Anyway?',
        message: '${failure.warnings.map((w) => '• ${w.text}').join('\n')}\n\nSave this schedule anyway?',
        type: ModalType.confirm,
        confirmText: 'Save Anyway',
        // 모달 자체의 Cancel 버튼과 라벨이 겹치지 않게 — 무엇으로 돌아가는지도 분명해진다.
        cancelText: 'Go Back',
      );
      if (ok == true && mounted) await _save(force: true);
      return;
    }
    if (failure != null && failure.isInvalid && failure.errors.isNotEmpty) {
      // 에러는 force 로도 못 넘는다 — 확인 버튼을 주지 않는다.
      if (!mounted) return;
      // 급여 기간 잠금은 **코드로** 분기한다(문자열 매칭 금지). 다른 에러와 달리
      // 화면에서 고칠 수 있는 값이 없어서, "무엇을 고치라"가 아니라 "누구에게
      // 요청하라"를 말해야 한다 — 날짜 제약을 푼 지금(D10-1) 과거 영업일을 열면
      // 실제로 자주 만나는 실패다.
      final locked = failure.errors.any((i) => i.code == kPayPeriodLocked);
      AppModal.show(
        context,
        title: locked ? 'Pay Period Closed' : 'Save Failed',
        message: failure.errors.map((i) => '• ${i.text}').join('\n'),
        type: ModalType.error,
      );
      return;
    }
    if (!mounted) return;
    AppModal.show(
      context,
      title: 'Save Failed',
      message: extractApiError(e, 'Could not save schedule.'),
      type: ModalType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _userId != null && _times.canSave && !_loading;
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
                        _operatingDayLine(),
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
                            Expanded(
                              child: _wheelTile(
                                'Start',
                                _times.startMinutes,
                                _startKey,
                                _setStart,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _wheelTile(
                                'End',
                                _times.endMinutes,
                                _endKey,
                                _setEnd,
                                dayOffset: _times.endDayOffset,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _lengthTile(),
                        if (!_times.isValid)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'End must be after start — set a length of at least 5 minutes.',
                              style: TextStyle(fontSize: 12, color: AppColors.danger),
                            ),
                          ),
                        _label('BREAK (OPTIONAL)'),
                        _breakSection(),
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
                      onPressed: (canSave && !_saving) ? () => _save() : null,
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

  /// 이 스케줄이 어느 영업일에 속하는지 + 실제 근무 구간 한 줄 요약.
  /// 새벽조는 달력 날짜가 영업일과 다르므로 `+1` 없이는 오해를 부른다.
  Widget _operatingDayLine() {
    final day = _operatingDay;
    final label = day == null
        ? 'Operating day —'
        : 'Operating day  ${rosterDayLabel(day)}';
    final bs = _times.breakStartMinutes;
    final be = _times.breakEndMinutes;
    final span =
        '${hhmmWithDayMarker(_times.startMinutes)} → ${hhmmWithDayMarker(_times.endMinutes, dayOffset: _times.endDayOffset)}'
        '  ·  ${formatDurationLabel(_times.durationMinutes)}'
        // 휴게도 같은 표기(`02:00 +1`)로 한 줄에 보여준다 — 화면마다 다른 표기를
        // 쓰면 같은 시각이 달라 보인다(D5-1/D5-4).
        '${bs == null || be == null ? '' : '\nBreak  ${hhmmWithDayMarker(bs, dayOffset: _times.breakStartDayOffset)} → ${hhmmWithDayMarker(be, dayOffset: _times.breakEndDayOffset)}'}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(span,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
        ],
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

  Widget _wheelTile(String label, int minutes, int keyEpoch, ValueChanged<int> onChanged, {int dayOffset = 0}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
              if (dayOffset > 0) ...[
                const SizedBox(width: 6),
                // `+1` 은 "다음 날"이라는 뜻. 26:00 같은 24 초과 표기는 쓰지 않는다.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+$dayOffset',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent)),
                ),
              ],
            ],
          ),
          TimeWheel(
            key: ValueKey('${label.toLowerCase()}-$keyEpoch'),
            initialMinutes: minutes,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 길이 필드 — 5분/30분 버튼.
  ///
  /// 휠 대신 버튼인 이유: 길이는 "조금 늘리고 줄이는" 조작이 대부분이고,
  /// 세 번째 휠을 넣으면 키오스크 화면에서 셋 다 좁아져 오조작이 는다.
  Widget _lengthTile() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Text('LENGTH',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
          const Spacer(),
          _stepButton('-30m', () => _bumpDuration(-30)),
          const SizedBox(width: 6),
          _stepButton('-5m', () => _bumpDuration(-scheduleStepMinutes)),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              formatDurationLabel(_times.durationMinutes),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 8),
          _stepButton('+5m', () => _bumpDuration(scheduleStepMinutes)),
          const SizedBox(width: 6),
          _stepButton('+30m', () => _bumpDuration(30)),
        ],
      ),
    );
  }

  /// 휴게 행 — 없으면 추가 버튼, 있으면 시작/종료 휠 + 삭제 버튼.
  ///
  /// 삭제 수단이 **필수**다(B4). 휴게를 손대지 않았는데 근무를 줄여 휴게가 밖으로
  /// 밀려나면 서버가 저장을 거부하는데, 지울 수 없으면 그 스케줄은 영영 못 고친다.
  Widget _breakSection() {
    if (!_times.hasBreak) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _times.isValid ? _addBreak : null,
          icon: const Icon(Icons.free_breakfast_outlined, size: 18),
          label: const Text('Add Break'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.textSecondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }
    final outside = !_times.breakInsideShift;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _wheelTile(
                'Break start',
                _times.breakStartMinutes!,
                _breakStartKey,
                _setBreakStart,
                dayOffset: _times.breakStartDayOffset,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _wheelTile(
                'Break end',
                _times.breakEndMinutes!,
                _breakEndKey,
                _setBreakEnd,
                dayOffset: _times.breakEndDayOffset,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Break ${formatDurationLabel(_times.breakWindow!.durationMinutes)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _removeBreak,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove Break'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ],
        ),
        if (outside)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'The break falls outside the shift. Move it inside, or remove it.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _stepButton(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        ),
      );
}
