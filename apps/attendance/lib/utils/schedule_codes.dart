/// 스케줄 검증의 에러/경고 코드 — **세 저장소가 공유하는 계약의 앱 측 단일 출처**.
///
/// 서버 쪽 짝은 `server/app/core/schedule_codes.py`. 목록이 같아야 하며, 코드 문자열
/// 리터럴을 다른 파일에 흩뿌리지 마라 (그러면 서버가 코드를 바꿔도 아무도 못 찾는다).
///
/// 계약 (D9)
/// ```
/// 400 {"detail": {"code": "SCHEDULE_INVALID", "message": ..,
///                 "errors": [{"code","params"}], "warnings": [...]}}
/// 409 {"detail": {"code": "SCHEDULE_WARNINGS_UNCONFIRMED", "message": ..,
///                 "warnings": [{"code","params"}], "retry": {"force": true}}}
/// ```
///
/// **문자열 매칭 금지.** `message` 는 구버전 클라용 fallback 이고, 문구는 코드 +
/// 파라미터로 여기서 구성한다. 선례는 `early_clock_in_logic.dart` 의
/// `kEarlyClockInReasonRequired` — 서버 문구가 바뀌어도 조용히 깨지지 않는다.
/// (예전 이 화면은 `msg.contains('overlap')` 로 분기했다. 서버가 그 단어를 쓰지
///  않게 되는 순간 안내가 사라지는데 아무도 모른다.)
///
/// 409 를 status 만 보고 판단하면 안 된다 — 409 는 이미 급여 잠금·폐점·PIN 충돌이
/// 쓰고 있어서, 그때도 "Save anyway" 버튼이 뜨게 된다. **최상위 `code` 로 식별한다.**

// ── 응답 최상위 코드 ────────────────────────────────────────

/// 400 — 에러가 하나 이상. force 로도 넘을 수 없다.
const String kScheduleInvalid = 'SCHEDULE_INVALID';

/// 409 — 경고만 있고 아직 확인받지 않았다. `force: true` 로 재요청하면 저장된다.
const String kScheduleWarningsUnconfirmed = 'SCHEDULE_WARNINGS_UNCONFIRMED';

// ── 에러 (차단, force 무효) ─────────────────────────────────

const String kZeroDuration = 'ZERO_DURATION';
const String kStartDateOutOfWindow = 'START_DATE_OUT_OF_WINDOW';

/// 시작 달력일이 자동 판정과 다르다 — **`date_override`/`force` 로도 못 넘는 400**
/// (2026-08-19). 영업일 구간 `[day_start(D), day_start(D+1))` 은 반열림이라 두 후보
/// 중 **하나만** 안에 든다. 자동값과 다른 날짜는 예외 없이 구간 밖이고, 그런 행은
/// 저장돼도 현장에서 못 쓴다(후보 조회에 안 잡히거나 이미 끝난 근무로 보인다).
///
/// params: `{auto, chosen, boundary, start_time, operating_day, suggested_operating_day}`.
/// 고칠 대상은 **날짜가 아니라 영업일** 이므로 문구는 그 안내로 끝나야 한다.
const String kStartDateMismatch = 'START_DATE_MISMATCH';

/// 근무 구간이 24시간을 넘는다 = 날짜 조립이 틀렸다는 뜻. `SHIFT_TOO_LONG`(경고)과 다르다.
const String kShiftSpanTooLong = 'SHIFT_SPAN_TOO_LONG';
const String kUserNotInStore = 'USER_NOT_IN_STORE';
const String kUserNotMarkedForStore = 'USER_NOT_MARKED_FOR_STORE';
const String kTimeNotOnGrid = 'TIME_NOT_ON_GRID';
const String kBreakPairIncomplete = 'BREAK_PAIR_INCOMPLETE';
const String kBreakReversed = 'BREAK_REVERSED';
const String kBreakOutsideShift = 'BREAK_OUTSIDE_SHIFT';
const String kPayPeriodLocked = 'PAY_PERIOD_LOCKED';

// ── 경고 (확인 후 진행) ─────────────────────────────────────

const String kOverlappingSchedule = 'OVERLAPPING_SCHEDULE';
const String kShiftTooLong = 'SHIFT_TOO_LONG';
const String kWeeklyOvertime = 'WEEKLY_OVERTIME';

/// 구 인코딩으로 저장돼 있던 시프트의 시각을 바꾸자 시작 달력일이 이동했다 —
/// 저장은 되되 무엇이 달라졌는지 사람이 보고 확인해야 한다.
const String kStartDateRecalculated = 'START_DATE_RECALCULATED';
/// 종료가 다음 영업일 경계를 넘는다 — 근무 뒷부분이 다음 영업일 창인데 라벨은 하나뿐이다.
/// 막지 않고 확인만 받는다(대개 영업일 오선택이거나 매장 경계 설정이 근무 패턴과 안 맞는 신호).
const String kEndAfterNextDayStart = 'END_AFTER_NEXT_DAY_START';
const String kStoreClosedDay = 'STORE_CLOSED_DAY';
const String kOperatingDayOverridden = 'OPERATING_DAY_OVERRIDDEN';

/// `START_DATE_MISMATCH` 한 줄 — **원인(경계와 시각의 관계) + 결과(출근 불가) +
/// 다음 행동(영업일 변경)**.
///
/// 방향은 `auto` 와 `operating_day` 로 가른다. 자동값이 영업일 당일이면 시작 시각이
/// 경계 이후라는 뜻이고, 영업일+1 이면 경계 이전이라는 뜻이다. 시각 문자열을 다시
/// 파싱하지 않는다 — 파싱 규칙이 하나 더 생기면 서버와 갈릴 자리가 늘어난다.
///
/// 400 이라 "그래도 저장" 이 없다. 그래서 이 문구의 일은 **고칠 방법을 알려주는 것**이다.
String _startDateMismatchText(Map<String, dynamic> params) {
  String? str(String key) {
    final v = params[key];
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  final auto = str('auto');
  final chosen = str('chosen');
  final boundary = str('boundary');
  final start = str('start_time');
  final operatingDay = str('operating_day');
  final suggested = str('suggested_operating_day');

  // params 가 없거나 모양이 다르면 문구를 지어내지 않고 공통 안내만 준다.
  if (auto == null || chosen == null || boundary == null || start == null) {
    return 'This start date is outside its operating day, so nobody could clock in. '
        'Change the operating day instead of the start date.';
  }

  final afterBoundary = operatingDay != null && auto == operatingDay;
  final relation = afterBoundary
      ? '$start is on or after the $boundary day start, so it belongs to $auto'
      : '$start is before the $boundary day start, so it belongs to $auto';
  final fix = suggested == null
      ? 'To work on $chosen, change the operating day instead.'
      : 'To work on $chosen, change the operating day to $suggested.';
  return '$relation — not $chosen. A shift starting on $chosen sits outside its '
      'operating day, so nobody can clock in on it. $fix';
}

/// 검증 항목 하나 (`{"code": ..., "params": {...}}`).
class ScheduleIssue {
  final String code;
  final Map<String, dynamic> params;

  const ScheduleIssue(this.code, [this.params = const {}]);

  static ScheduleIssue? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final code = raw['code']?.toString();
    if (code == null || code.isEmpty) return null;
    final p = raw['params'];
    return ScheduleIssue(
      code,
      p is Map ? Map<String, dynamic>.from(p) : const {},
    );
  }

  /// 사람이 읽을 한 줄 — **원인 + 다음 행동**(에러 UX 표준).
  ///
  /// 모르는 코드는 문구를 지어내지 않고 코드를 그대로 보여준다. 새 코드가 서버에만
  /// 생겼을 때 "조용한 실패" 대신 무엇이 걸렸는지는 알 수 있어야 한다.
  String get text {
    switch (code) {
      case kZeroDuration:
        return 'The shift length is 0. Set an end time after the start time.';
      case kStartDateOutOfWindow:
        return 'The start date is outside this operating day. Pick a time inside the day.';
      case kStartDateMismatch:
        return _startDateMismatchText(params);
      case kShiftSpanTooLong:
        return 'This shift spans more than 24 hours. Check the start and end dates.';
      case kUserNotInStore:
      case kUserNotMarkedForStore:
        return 'This employee is not assigned to this store. Pick another employee.';
      case kTimeNotOnGrid:
        final step = params['step_minutes'] ?? 5;
        return 'Times must be in $step-minute steps. Adjust the time wheel.';
      case kBreakPairIncomplete:
        return 'The break needs both a start and an end. Set both, or remove the break.';
      case kBreakReversed:
        return 'The break ends before it starts. Fix the break times.';
      case kBreakOutsideShift:
        return 'The break falls outside the shift. Move the break inside, or remove it.';
      case kPayPeriodLocked:
        return 'This pay period is closed. Ask payroll to reopen it.';
      case kOverlappingSchedule:
        return 'This employee already has an overlapping shift.';
      case kShiftTooLong:
        final limit = params['limit_hours'];
        return limit == null
            ? 'This shift is longer than the store limit.'
            : 'This shift is longer than the ${limit}h store limit.';
      case kWeeklyOvertime:
        return 'This puts the employee over the weekly hour limit.';
      case kEndAfterNextDayStart:
        final b = params['boundary'];
        final nd = params['next_operating_day'];
        return b == null
            ? 'This shift runs into the next business day. Its hours still count on this operating day.'
            : 'This shift runs past $b, when the next business day'
                '${nd == null ? '' : ' ($nd)'} starts. '
                'Its hours will still count on this operating day.';
      case kStartDateRecalculated:
        final d = params['start_date'];
        return d == null
            ? 'The calendar date moved to match the store day boundary. Check the dates before saving.'
            : 'The calendar date moved to $d to match the store day boundary. Check it before saving.';
      case kStoreClosedDay:
        return 'The store is closed on this day.';
      case kOperatingDayOverridden:
        return 'The operating day differs from the automatic result.';
      default:
        return code;
    }
  }
}

/// 400/409 응답 본문을 계약대로 읽은 결과. 계약 밖 응답이면 null 이 온다.
class ScheduleValidationFailure {
  /// 최상위 코드 — 분기는 **오직 이 값**으로 한다.
  final String code;
  final List<ScheduleIssue> errors;
  final List<ScheduleIssue> warnings;

  const ScheduleValidationFailure({
    required this.code,
    this.errors = const [],
    this.warnings = const [],
  });

  /// 경고만 있고 확인이 안 된 상태 — `force: true` 재요청으로 저장할 수 있다.
  bool get isUnconfirmedWarnings => code == kScheduleWarningsUnconfirmed;

  /// 차단 — 확인으로도 넘을 수 없다.
  bool get isInvalid => code == kScheduleInvalid;
}

/// dio 예외에서 스케줄 검증 실패를 꺼낸다. 계약 형태가 아니면 null.
///
/// 이 함수가 null 을 주면 호출부는 **일반 에러 처리로 폴백**해야 한다 — 세션 만료나
/// 네트워크 오류까지 확인 모달로 삼키면 안 된다.
ScheduleValidationFailure? parseScheduleFailure(Object error) {
  dynamic data;
  try {
    data = (error as dynamic).response?.data;
  } catch (_) {
    return null;
  }
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is! Map) return null;
  final code = detail['code']?.toString();
  if (code != kScheduleInvalid && code != kScheduleWarningsUnconfirmed) return null;
  List<ScheduleIssue> pick(String key) {
    final raw = detail[key];
    if (raw is! List) return const [];
    return raw.map(ScheduleIssue.tryParse).whereType<ScheduleIssue>().toList();
  }

  return ScheduleValidationFailure(
    code: code!,
    errors: pick('errors'),
    warnings: pick('warnings'),
  );
}
