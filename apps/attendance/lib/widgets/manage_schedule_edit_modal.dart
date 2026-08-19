/// Manage 스케줄 추가/수정 중앙 모달.
///
/// STAFF(필수) / WORK ROLE(선택) / **Start · End · Length 3필드**(D5-2).
///
/// **날짜가 먼저 읽힌다**(2026-08-18 시프트 날짜 트랙). 끝점 하나 =
/// `[날짜 버튼 48dp]` 위 + `[시각 휠]` 아래이고, 상단 바에 영업일과 경계 시각이
/// 항상 떠 있다. 예전엔 화면 어디에도 "이 시프트가 며칠에 시작하는지"가 없어서
/// 잘못 저장된 날짜(1439분 조기출근 오탐)를 한 달 넘게 아무도 못 봤다.
///
/// 날짜는 입력값이 아니라 **파생값**이다 — `영업일 + (시작 < day_start ? 1 : 0)`.
/// 판정은 `shift_date_logic.dart` 한 곳에만 있다(화면에서 재계산 금지). 시각을
/// 바꾸면 날짜가 따라 움직이고, 그때 사람이 골랐던 날짜는 **무효화된다**(D4).
///
/// 저장은 **항상 전체 전송**이다(D7-3). 기본은 지금처럼 HH:mm 만 보내고 서버가
/// 조립한다. 사람이 자동값과 **다른 날짜를 직접 고른 경우에만** 명시
/// `start_at`/`end_at` + `date_override:true` 를 싣는다(C2) — 그 표시가 없는 불일치는
/// 사람의 선택이 아니라 클라이언트 버그라 서버가 400 으로 막는다.
///
/// 경고는 삼키지 않는다: 409 `SCHEDULE_WARNINGS_UNCONFIRMED` 를 받으면 무엇이
/// 걸렸는지 보여주고, 매니저가 확인한 경우에만 `force: true` 로 재요청한다(D9-1).
///
/// **BREAK 행**(F6): 휴게는 근무 시작 기준 오프셋으로 들고 있어서 시작을 옮기면
/// 함께 움직인다(B2). 원치 않으면 지우고 다시 넣는다(B4) — 그래서 지우기 수단이
/// 필수다. 휴게 끝점도 근무와 **같은 날짜 문법**으로 읽힌다.
///
/// **탭 요소는 전부 휠 위 또는 오버레이에 둔다.** 휠(ListWheelScrollView) 바로 아래에
/// 작은 탭 타겟을 두면 플링 직후 손가락이 멈추는 자리라 오탭이 난다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/attendance_device_provider.dart';
import '../providers/attendance_manage_provider.dart';
import '../services/attendance_device_service.dart';
import '../utils/api_error_display.dart' show extractApiError;
import '../utils/roster_day.dart';
import '../utils/schedule_codes.dart';
import '../utils/schedule_edit_logic.dart';
import '../utils/shift_date_logic.dart';
import '../utils/store_time.dart';
import 'time_wheel.dart';

/// 날짜 시트를 여는 끝점. 네 끝점이 같은 시트를 쓴다.
enum _DateTarget { start, end, breakStart, breakEnd }

/// 시트에 뜨는 후보 1개. **자유 캘린더는 없다** — 후보는 언제나 두 개뿐이다.
class _DateOption {
  final DateTime date;
  final String caption;
  final bool suggested;
  final bool selected;

  /// 고를 수 없는 후보(고르면 근무가 24시간을 넘거나 휴게가 근무 밖으로 나간다).
  /// 숨기지 않고 **이유와 함께 흐리게** 남긴다 — 없어진 선택지는 설명이 안 된다.
  final String? disabledReason;

  /// 이 후보를 고르면 근무 길이가 얼마가 되는지 (종료 날짜 후보에만 있다).
  final String? lengthPreview;

  final VoidCallback? onPick;

  const _DateOption({
    required this.date,
    required this.caption,
    this.suggested = false,
    this.selected = false,
    this.disabledReason,
    this.lengthPreview,
    this.onPick,
  });
}

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

  /// 사람이 직접 고른 시작 날짜 오프셋(0 또는 1). **자동값과 같으면 null** 이다 —
  /// 자동값과 같은데 override 로 잡아두면, 나중에 시각이 바뀌었을 때 옛 날짜가
  /// 눌러앉는다(콘솔 편집 모달이 정확히 그래서 24건을 오염시켰다).
  int? _startOffsetOverride;

  /// 열려 있는 날짜 시트. 모달 **안쪽** 오버레이라 모달 높이는 변하지 않는다.
  _DateTarget? _sheet;

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
      //
      // ⚠️ 기존 행의 날짜 오프셋을 override 로 **잡지 않는다**(D4 마지막 줄). 열자마자
      //    잡아두면 시각만 바꿔도 옛 날짜가 살아남는다 — 이번 사고의 직접 원인이다.
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

  /// 매장 영업일 경계. 서버가 아직 안 내려주면 null 이고, 그때는 **날짜 UI 를 끈다**
  /// (경계를 모른 채 계산한 날짜는 틀린 날짜다 — 서버 조립 결과만 믿는다).
  DayStartConfig? get _dayStart =>
      ref.read(attendanceDeviceProvider).device?.dayStart;

  /// 지금 상태의 달력 날짜. 경계나 영업일을 모르면 null.
  ShiftDates? get _dates {
    final day = _operatingDay;
    final cfg = _dayStart;
    if (day == null || cfg == null) return null;
    return resolveShiftDates(
      operatingDay: day,
      dayStart: cfg,
      times: _times,
      startOffsetOverride: _startOffsetOverride,
    );
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
      // 시작 시각이 바뀌었으면 사람이 골랐던 날짜는 무효다(D4).
      if (s != null) _startOffsetOverride = null;
      _startKey++;
      _endKey++;
    });
  }

  void _setStart(int minutes) {
    setState(() {
      _times = _times.withStart(minutes);
      // 시각이 바뀌면 날짜는 **자동값이 이긴다**(D4). 이 한 줄이 이번 사고의 수정점이다.
      _startOffsetOverride = null;
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

  /// 종료 시각 변경 — 길이만 바뀐다. **시작 날짜 선택은 유지**된다(D4 표).
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

      // 기본은 HH:mm 만 — 서버가 경계 규칙으로 조립한다(C2). 명시 날짜는 사람이
      // 자동값과 **다른 날짜를 직접 고른 경우에만** 싣는다. 항상 실으면 클라가 들고
      // 있던 옛 날짜가 서버 판정을 이겨버린다(= 이번 사고의 구조).
      final dates = _dates;
      final overridden = dates != null && dates.isStartDateOverridden;
      final startAt = overridden ? wallClockIso(dates.startDate, _times.startMinutes) : null;
      final endAt = overridden
          ? wallClockIso(dates.startDate, _times.startMinutes + _times.durationMinutes)
          : null;
      final breakStartAt = overridden && _times.breakWindow != null
          ? wallClockIso(dates.startDate,
              _times.startMinutes + _times.breakWindow!.startOffsetMinutes)
          : null;
      final breakEndAt = overridden && _times.breakWindow != null
          ? wallClockIso(
              dates.startDate,
              _times.startMinutes +
                  _times.breakWindow!.startOffsetMinutes +
                  _times.breakWindow!.durationMinutes)
          : null;

      if (_isEdit) {
        await service.manageUpdateSchedule(
          scheduleId: widget.existing!.scheduleId,
          userId: _userId,
          workRoleId: _workRoleId,
          startHHmm: start,
          endHHmm: end,
          breakStartHHmm: breakStart,
          breakEndHHmm: breakEnd,
          startAt: startAt,
          endAt: endAt,
          breakStartAt: breakStartAt,
          breakEndAt: breakEndAt,
          dateOverride: overridden,
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
          startAt: startAt,
          endAt: endAt,
          breakStartAt: breakStartAt,
          breakEndAt: breakEndAt,
          dateOverride: overridden,
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
  ///
  /// 날짜 트랙의 새 코드도 여기로 들어온다 — 409 `START_DATE_RECALCULATED` 는 확인
  /// 흐름(경고), 400 `START_DATE_MISMATCH` / `SHIFT_SPAN_TOO_LONG` 은 차단이다.
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
    // device 를 watch 해야 day_start 가 뒤늦게 도착했을 때 날짜 UI 가 켜진다.
    ref.watch(attendanceDeviceProvider);
    final l10n = AppL10n.of(context);
    final canSave = _userId != null && _times.canSave && !_loading;
    final dates = _dates;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Stack(
          children: [
            Padding(
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
                            _operatingDayBar(l10n),
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
                            // LENGTH 를 TIME 라벨 행으로 올려 Start↔End 를 붙인다 —
                            // 두 끝점 사이를 가로막던 단독 행이 사라진다.
                            _timeHeader(l10n),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _endpointTile(
                                    l10n: l10n,
                                    dateLabel: l10n.mgSchedStartDate,
                                    date: dates?.startDate,
                                    offsetDays: dates?.startOffsetDays ?? 0,
                                    target: _DateTarget.start,
                                    wheelLabel: 'start',
                                    minutes: _times.startMinutes,
                                    keyEpoch: _startKey,
                                    onChanged: _setStart,
                                    fallbackLabel: 'START',
                                    fallbackOffset: 0,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _endpointTile(
                                    l10n: l10n,
                                    dateLabel: l10n.mgSchedEndDate,
                                    date: dates?.endDate,
                                    offsetDays: dates?.endOffsetDays ?? 0,
                                    target: _DateTarget.end,
                                    wheelLabel: 'end',
                                    minutes: _times.endMinutes,
                                    keyEpoch: _endKey,
                                    onChanged: _setEnd,
                                    fallbackLabel: 'END',
                                    fallbackOffset: _times.endOffsetFromStartDate,
                                  ),
                                ),
                              ],
                            ),
                            if (dates != null && dates.isStartDateOverridden)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  l10n.mgSchedManualDate(rosterDayLabel(
                                      shiftDateOnly(dates.operatingDay)
                                          .add(Duration(days: dates.autoStartOffsetDays)))),
                                  style: const TextStyle(fontSize: 12, color: AppColors.warning),
                                ),
                              ),
                            if (!_times.isValid)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'End must be after start — set a length of at least 5 minutes.',
                                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                                ),
                              ),
                            _label('BREAK (OPTIONAL)'),
                            _breakSection(l10n, dates),
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
            if (_sheet != null && dates != null) ..._dateSheet(l10n, _sheet!, dates),
          ],
        ),
      ),
    );
  }

  /// 영업일 + 경계 시각 한 줄. **평상시에도 늘 떠 있다** — 숨기면 예외 상태에서만
  /// 나타나는 정보가 되고, 그러면 매니저가 그 줄을 읽는 법을 배우지 못한다.
  Widget _operatingDayBar(AppL10n l10n) {
    final day = _operatingDay;
    final cfg = _dayStart;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(l10n.mgSchedOperatingDay,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(day == null ? '—' : rosterDayLabel(day),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
          ),
          const Spacer(),
          if (day != null && cfg != null)
            Text(
              l10n.mgSchedDayStarts(cfg.labelFor(shiftDateOnly(day).add(const Duration(days: 1)))),
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  /// TIME 라벨 + LENGTH 스테퍼 한 행(48dp 타겟). 스테퍼는 휠 **위**에 있다.
  Widget _timeHeader(AppL10n l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text(l10n.mgSchedTime,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
            const Text(' *', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
            const Spacer(),
            _stepButton('-30m', () => _bumpDuration(-30)),
            const SizedBox(width: 6),
            _stepButton('-5m', () => _bumpDuration(-scheduleStepMinutes)),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatDurationLabel(_times.durationMinutes),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    // height 를 고정하지 않으면 폰트 leading 때문에 48dp 행을 넘긴다.
                    style: const TextStyle(
                        fontSize: 18, height: 1.2, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  Text(l10n.mgSchedLength,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.7)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _stepButton('+5m', () => _bumpDuration(scheduleStepMinutes)),
            const SizedBox(width: 6),
            _stepButton('+30m', () => _bumpDuration(30)),
          ],
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

  /// 끝점 하나 = **날짜 버튼(위) + 시각 휠(아래)**. "어느 날 → 몇 시" 순서로 읽힌다.
  ///
  /// [date] 가 null 이면(경계 미수신) 날짜를 짐작하지 않고 예전 라벨 행으로 떨어진다.
  Widget _endpointTile({
    required AppL10n l10n,
    required String dateLabel,
    required DateTime? date,
    required int offsetDays,
    required _DateTarget target,
    required String wheelLabel,
    required int minutes,
    required int keyEpoch,
    required ValueChanged<int> onChanged,
    required String fallbackLabel,
    required int fallbackOffset,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          if (date != null)
            _dateButton(
              l10n: l10n,
              label: dateLabel,
              date: date,
              offsetDays: offsetDays,
              target: target,
            )
          else
            _fallbackLabelRow(fallbackLabel, fallbackOffset),
          const SizedBox(height: 6),
          TimeWheel(
            key: ValueKey('$wheelLabel-$keyEpoch'),
            initialMinutes: minutes,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 경계를 모를 때의 예전 표기 — 라벨 + `+1` 배지. 서버 조립 결과만 믿는 상태다.
  Widget _fallbackLabelRow(String label, int dayOffset) => SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
            if (dayOffset > 0) ...[
              const SizedBox(width: 6),
              _plusBadge(dayOffset, AppColors.accent, AppColors.accent.withValues(alpha: 0.14)),
            ],
          ],
        ),
      );

  Widget _plusBadge(int offset, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text('+$offset',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg)),
      );

  /// 날짜 버튼(48dp). **`+1` 은 별도 경고 줄이 아니라 버튼 자체가 말한다** —
  /// 색·배지·캡션이 붙을 뿐 높이는 그대로라 레이아웃이 튀지 않는다.
  Widget _dateButton({
    required AppL10n l10n,
    required String label,
    required DateTime date,
    required int offsetDays,
    required _DateTarget target,
  }) {
    final next = offsetDays > 0;
    final open = _sheet == target;
    return InkWell(
      onTap: _saving ? null : () => setState(() => _sheet = target),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(
          color: next ? AppColors.warningBg : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: open
                ? AppColors.accent
                : (next ? AppColors.warning.withValues(alpha: 0.55) : AppColors.border),
            width: open ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(next ? '$label · ${l10n.mgSchedNextDay}' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: next ? AppColors.warning : AppColors.textMuted)),
                  Row(
                    children: [
                      if (next) ...[
                        _plusBadge(offsetDays, AppColors.white, AppColors.warning),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(rosterDayLabel(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: next ? AppColors.warning : AppColors.text)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// 휴게 행 — 없으면 추가 버튼, 있으면 (날짜 버튼 + 휠) 두 타일 + 삭제 버튼.
  ///
  /// 삭제 수단이 **필수**다(B4). 휴게를 손대지 않았는데 근무를 줄여 휴게가 밖으로
  /// 밀려나면 서버가 저장을 거부하는데, 지울 수 없으면 그 스케줄은 영영 못 고친다.
  Widget _breakSection(AppL10n l10n, ShiftDates? dates) {
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
              child: _endpointTile(
                l10n: l10n,
                dateLabel: l10n.mgSchedBreakStartDate,
                date: dates?.breakStartDate(_times),
                offsetDays: dates?.breakStartOffsetDays(_times) ?? 0,
                target: _DateTarget.breakStart,
                wheelLabel: 'break start',
                minutes: _times.breakStartMinutes!,
                keyEpoch: _breakStartKey,
                onChanged: _setBreakStart,
                fallbackLabel: 'BREAK START',
                fallbackOffset: _times.breakStartOffsetFromStartDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _endpointTile(
                l10n: l10n,
                dateLabel: l10n.mgSchedBreakEndDate,
                date: dates?.breakEndDate(_times),
                offsetDays: dates?.breakEndOffsetDays(_times) ?? 0,
                target: _DateTarget.breakEnd,
                wheelLabel: 'break end',
                minutes: _times.breakEndMinutes!,
                keyEpoch: _breakEndKey,
                onChanged: _setBreakEnd,
                fallbackLabel: 'BREAK END',
                fallbackOffset: _times.breakEndOffsetFromStartDate,
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 48),
              ),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          constraints: const BoxConstraints(minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        ),
      );

  // ── 날짜 선택 시트 ────────────────────────────────────────
  // 모달 **안쪽** 오버레이라 모달 높이는 0dp 도 늘지 않는다. 후보는 언제나 두 개다 —
  // 캘린더 위젯을 열면 창 밖 날짜로 튀는 경로가 다시 생긴다(2026-07-10 의 재발).

  List<Widget> _dateSheet(AppL10n l10n, _DateTarget target, ShiftDates dates) {
    final options = _optionsFor(target, dates);
    final (title, sub) = switch (target) {
      _DateTarget.start => (
          l10n.mgSchedPickStartDate,
          l10n.mgSchedPickStartSub(
              minutesToHHmm(_times.startMinutes), rosterDayLabel(dates.operatingDay)),
        ),
      _DateTarget.end => (l10n.mgSchedPickEndDate, l10n.mgSchedPickEndSub),
      _DateTarget.breakStart => (l10n.mgSchedPickBreakStartDate, l10n.mgSchedPickBreakSub),
      _DateTarget.breakEnd => (l10n.mgSchedPickBreakEndDate, l10n.mgSchedPickBreakSub),
    };
    final cfg = _dayStart;
    return [
      Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => _sheet = null),
          child: Container(color: Colors.black.withValues(alpha: 0.44)),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(sub,
                  style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
              if (target == _DateTarget.start && cfg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.mgSchedBoundaryNote(cfg.labelFor(
                        shiftDateOnly(dates.operatingDay).add(const Duration(days: 1)))),
                    style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...options.map((o) => _optionRow(l10n, o)),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => setState(() => _sheet = null),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(l10n.mgSchedCancel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _optionRow(AppL10n l10n, _DateOption o) {
    final disabled = o.disabledReason != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                o.onPick?.call();
                setState(() => _sheet = null);
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: o.selected ? AppColors.accentBg : AppColors.bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: o.selected ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rosterDayLabel(o.date),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: disabled ? AppColors.textMuted : AppColors.text)),
                    const SizedBox(height: 2),
                    Text(o.disabledReason ?? o.lengthPreview ?? o.caption,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: disabled ? AppColors.danger : AppColors.textSecondary)),
                  ],
                ),
              ),
              if (o.suggested)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: o.selected ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(l10n.mgSchedSuggested,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: o.selected ? AppColors.white : AppColors.textSecondary)),
                ),
              if (o.selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20, color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 끝점별 후보 2개. 계산은 [ShiftDates] 규칙을 그대로 쓰고, 여기서 날짜 산술을
  /// 새로 하지 않는다.
  List<_DateOption> _optionsFor(_DateTarget target, ShiftDates dates) {
    final l10n = AppL10n.of(context);
    switch (target) {
      case _DateTarget.start:
        // 후보는 영업일 / 영업일+1 **두 개뿐**이고, 그중 고를 수 있는 건 자동값 하나다
        // (2026-08-19). 영업일 구간은 반열림이라 다른 후보는 예외 없이 구간 밖이고,
        // 저장해도 현장에서 못 쓴다 — 서버도 400 START_DATE_MISMATCH 로 거부한다.
        //
        // 그래도 **지우지 않는다.** 종료 후보의 24h 초과 처리와 같은 방식으로, 보이되
        // 흐리고 이유를 단다. 숨기면 "왜 하나뿐이지"에 화면이 대답하지 못한다.
        final startsBeforeBoundary = dates.autoStartOffsetDays == 1;
        final boundaryLabel = _dayStart?.labelFor(
            shiftDateOnly(dates.operatingDay).add(const Duration(days: 1)));
        final startLabel = minutesToHHmm(_times.startMinutes);
        final opts = [0, 1].map((offset) {
          final auto = offset == dates.autoStartOffsetDays;
          return _DateOption(
            date: shiftDateOnly(dates.operatingDay).add(Duration(days: offset)),
            caption: offset == 0 ? l10n.mgSchedOptOperatingDay : l10n.mgSchedOptNextDay,
            suggested: auto,
            selected: offset == dates.startOffsetDays,
            disabledReason: auto || boundaryLabel == null
                ? null
                : (startsBeforeBoundary
                    ? l10n.mgSchedOptOutsideBefore(startLabel, boundaryLabel)
                    : l10n.mgSchedOptOutsideAfter(startLabel, boundaryLabel)),
            onPick: auto
                ? () => setState(() {
                      // 자동값이 곧 유일한 후보다 — override 는 잡지 않는다(D4).
                      _startOffsetOverride = null;
                    })
                : null,
          );
        }).toList();
        // 자동값을 먼저 보여준다 — 첫 줄이 기본 선택지다.
        opts.sort((a, b) => (b.suggested ? 1 : 0) - (a.suggested ? 1 : 0));
        return opts;

      case _DateTarget.end:
        // 종료 날짜 후보는 시작일 / 시작일+1 두 개. 고르면 **길이가 재계산**된다.
        final current = _times.endOffsetFromStartDate;
        return [0, 1].map((offset) {
          final duration = _times.durationMinutes + (offset - current) * minutesPerDay;
          final tooLong = duration > minutesPerDay;
          final tooShort = duration <= 0;
          return _DateOption(
            date: dates.startDate.add(Duration(days: offset)),
            caption: offset == 0 ? l10n.mgSchedOptShiftStartDay : l10n.mgSchedOptDayAfterStart,
            suggested: offset == current,
            selected: offset == current,
            lengthPreview: l10n.mgSchedOptLength(formatDurationLabel(duration)),
            disabledReason: tooLong
                ? l10n.mgSchedOptTooLong
                : (tooShort ? l10n.mgSchedOptNegative : null),
            onPick: offset == current
                ? null
                : () => setState(() {
                      _times = _times.withDuration(duration);
                      _endKey++;
                    }),
          );
        }).toList();

      case _DateTarget.breakStart:
      case _DateTarget.breakEnd:
        // 휴게는 근무 시작 기준 오프셋이라 날짜가 **근무를 따라온다**. 다른 날을
        // 고르면 휴게가 근무창 밖으로 나가므로 후보는 보이되 고를 수 없다 —
        // 숨기면 "왜 여기만 못 고르지"라는 질문에 화면이 대답하지 못한다.
        final current = target == _DateTarget.breakStart
            ? dates.breakStartOffsetDays(_times)
            : dates.breakEndOffsetDays(_times);
        final currentDate = target == _DateTarget.breakStart
            ? dates.breakStartDate(_times)!
            : dates.breakEndDate(_times)!;
        final other = currentDate.add(Duration(days: current == dates.startOffsetDays ? 1 : -1));
        return [
          _DateOption(
            date: currentDate,
            caption: l10n.mgSchedPickBreakSub,
            suggested: true,
            selected: true,
          ),
          _DateOption(
            date: other,
            caption: l10n.mgSchedOptBreakLocked,
            disabledReason: l10n.mgSchedOptBreakLocked,
          ),
        ];
    }
  }
}
