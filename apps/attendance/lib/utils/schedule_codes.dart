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
const String kStartAfterDayBoundary = 'START_AFTER_DAY_BOUNDARY';
const String kStartBeforeDayBoundary = 'START_BEFORE_DAY_BOUNDARY';
const String kStoreClosedDay = 'STORE_CLOSED_DAY';
const String kOperatingDayOverridden = 'OPERATING_DAY_OVERRIDDEN';

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
      case kStartAfterDayBoundary:
        return 'The start is after the day boundary — it may belong to the next operating day.';
      case kStartBeforeDayBoundary:
        return 'The start is before the day boundary — it may belong to the previous operating day.';
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
