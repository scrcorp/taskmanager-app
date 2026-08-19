/// 시프트의 **달력 날짜** 판정 — 앱 측 **단일 출처**.
///
/// 스케줄은 `operating_day`(영업일 라벨)와 `start_at`/`end_at`(벽시계 datetime)을
/// 따로 저장한다. 둘은 같은 날일 수도, 하루 어긋날 수도 있다 — 매장 영업일 경계
/// (`day_start`) 이전에 시작하는 시프트는 달력상 **영업일 다음 날**이 정상이다.
///
/// 규칙 (서버 `app/utils/timezone.py` / 콘솔 `src/lib/scheduleTime.ts` 와 같은 두 줄):
/// ```
/// so = 시작 시각 <  day_start(operating_day + 1) ? 1 : 0   → 시작 날짜 = 영업일 + so
/// eo = 종료 시각 <= 시작 시각                     ? 1 : 0   → 종료 날짜 = 시작 날짜 + eo
/// ```
///
/// **오프셋 기준은 영업일이다.** 예전 [ShiftTimes.endOffsetFromStartDate] 는 시작
/// 기준이라 "경계 이전 시작이라 **시작**이 +1일" 이라는 상태를 아예 표현하지 못했고,
/// 그래서 화면에 날짜가 없었다 — 2026-08 의 1439분 조기출근 오탐을 한 달 넘게
/// 아무도 육안으로 잡지 못한 이유가 그것이다.
///
/// 이 파일 밖에서 오프셋을 다시 계산하지 마라. 화면마다 재구현하면 같은 시프트가
/// 화면마다 다른 날짜로 보이고, 어느 쪽이 맞는지 아무도 모르게 된다.
library;

import 'schedule_edit_logic.dart';

/// 서버 `_WEEKDAY_KEYS` 와 같은 순서·같은 키. Dart `DateTime.weekday` 는 월=1 이라
/// `weekday - 1` 이 그대로 인덱스가 된다.
const List<String> kDayStartWeekdayKeys = [
  'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
];

/// 서버가 매장 설정을 못 읽었을 때 쓰는 기본 경계 — 서버 `DEFAULT_DAY_START_TIME`.
/// **폴백일 뿐 판정 근거가 아니다.** 서버가 값을 안 내려주면 앱은 날짜 UI 자체를
/// 켜지 않는다([DayStartConfig.tryParse] 가 null 을 준다).
const String kDefaultDayStartHHmm = '06:00';

/// 매장 영업일 경계 — 요일별 "HH:mm".
///
/// 서버는 7키를 모두 채워 내려준다(`day_start_map`). 그래도 요일 키가 빠진 형태나
/// 단일 문자열(`"11:00"`)로 오는 경우까지 받아들인다 — 계약이 확정되기 전 배포된
/// 앱이 조용히 날짜를 틀리게 만드는 것보다, 읽을 수 있는 형태를 다 읽는 편이 안전하다.
class DayStartConfig {
  /// 요일 키('mon'..'sun') → 경계 분값(0..1439).
  final Map<String, int> byWeekday;

  /// 요일 키가 없을 때 쓰는 값(`all` 또는 단일 문자열로 온 값).
  final int fallbackMinutes;

  const DayStartConfig({
    this.byWeekday = const {},
    required this.fallbackMinutes,
  });

  /// 서버 응답 필드에서 만든다. 읽을 수 없으면 **null** — 호출부는 null 을
  /// "경계를 모른다"로 다루고 날짜 판정을 하지 않아야 한다(서버 조립 결과만 표시).
  ///
  /// 받아들이는 형태:
  ///   * `"11:00"`                     (매장 전체 단일 경계)
  ///   * `{"all": "11:00"}`            (저장 형태 그대로)
  ///   * `{"mon": "11:00", ... }`      (요일별 — 서버가 펼쳐 내려주는 형태)
  static DayStartConfig? tryParse(dynamic raw) {
    if (raw is String) {
      final m = hhmmToMinutes(raw);
      return m == null ? null : DayStartConfig(fallbackMinutes: m);
    }
    if (raw is Map) {
      final byWeekday = <String, int>{};
      for (final key in kDayStartWeekdayKeys) {
        final m = hhmmToMinutes(raw[key]?.toString());
        if (m != null) byWeekday[key] = m;
      }
      final all = hhmmToMinutes(raw['all']?.toString());
      if (byWeekday.isEmpty && all == null) return null;
      return DayStartConfig(
        byWeekday: byWeekday,
        fallbackMinutes: all ?? byWeekday.values.first,
      );
    }
    return null;
  }

  /// 그 **달력 날짜**의 경계 분값. 요일별 설정이면 그 요일 값을 쓴다.
  int minutesFor(DateTime date) =>
      byWeekday[kDayStartWeekdayKeys[date.weekday - 1]] ?? fallbackMinutes;

  /// 화면 표기용 "HH:mm".
  String labelFor(DateTime date) => minutesToHHmm(minutesFor(date));
}

/// 시분초를 버린 날짜만.
DateTime shiftDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 벽시계 datetime 을 서버 계약 문자열 "YYYY-MM-DDTHH:MM" 로. 타임존 표기를 붙이지
/// 않는다 — 붙이는 순간 기기 타임존이 섞여 들어와 매장 벽시계가 아니게 된다.
String wallClockIso(DateTime date, int minutes) {
  final base = shiftDateOnly(date).add(Duration(days: minutes ~/ minutesPerDay));
  final m = wrapMinutes(minutes);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${base.year.toString().padLeft(4, '0')}-${two(base.month)}-${two(base.day)}'
      'T${two(m ~/ 60)}:${two(m % 60)}';
}

/// 자동 판정된 시작 날짜 오프셋 — `시작 시각 < day_start(영업일+1) ? 1 : 0`.
///
/// 경계는 **영업일 다음 날**의 것을 본다(요일별 설정일 때 값이 달라진다). 서버
/// `_kiosk_shift_iso` 와 같은 선택이며, 어긋나면 화면 날짜와 저장 날짜가 갈린다.
int autoStartOffsetDays({
  required DateTime operatingDay,
  required DayStartConfig dayStart,
  required int startMinutes,
}) {
  final nextDay = shiftDateOnly(operatingDay).add(const Duration(days: 1));
  return wrapMinutes(startMinutes) < dayStart.minutesFor(nextDay) ? 1 : 0;
}

/// 편집 중인 시프트의 **달력 날짜 묶음**. 오프셋은 전부 **영업일 기준**이다.
class ShiftDates {
  /// 영업일 라벨(날짜만).
  final DateTime operatingDay;

  /// 자동 판정된 시작 오프셋 — 사람이 고른 값과 비교해 SUGGESTED 를 표시한다.
  final int autoStartOffsetDays;

  /// 실제 적용될 시작 오프셋 (사람이 골랐으면 그 값).
  final int startOffsetDays;

  /// 시작 날짜에서 종료 날짜까지의 일수. 길이에서 파생된다(24시간 이상도 그대로).
  final int endOffsetFromStartDate;

  const ShiftDates({
    required this.operatingDay,
    required this.autoStartOffsetDays,
    required this.startOffsetDays,
    required this.endOffsetFromStartDate,
  });

  DateTime get startDate =>
      shiftDateOnly(operatingDay).add(Duration(days: startOffsetDays));

  DateTime get endDate => startDate.add(Duration(days: endOffsetFromStartDate));

  /// 종료 날짜가 영업일보다 며칠 뒤인가 — 화면의 `+N` 배지는 이 값으로 붙인다.
  int get endOffsetDays => startOffsetDays + endOffsetFromStartDate;

  /// 사람이 자동 판정과 다른 날짜를 골랐는가. 저장 시 `date_override:true` 조건.
  bool get isStartDateOverridden => startOffsetDays != autoStartOffsetDays;

  /// 휴게 시작/종료의 달력 날짜 (근무 시작 기준 오프셋에서 파생).
  DateTime? breakStartDate(ShiftTimes times) => _breakDate(times, 0);

  DateTime? breakEndDate(ShiftTimes times) =>
      _breakDate(times, times.breakWindow?.durationMinutes ?? 0);

  int breakStartOffsetDays(ShiftTimes times) => _breakOffset(times, 0);

  int breakEndOffsetDays(ShiftTimes times) =>
      _breakOffset(times, times.breakWindow?.durationMinutes ?? 0);

  DateTime? _breakDate(ShiftTimes times, int extraMinutes) {
    final w = times.breakWindow;
    if (w == null) return null;
    return startDate.add(Duration(days: _breakOffset(times, extraMinutes) - startOffsetDays));
  }

  int _breakOffset(ShiftTimes times, int extraMinutes) {
    final w = times.breakWindow;
    if (w == null) return startOffsetDays;
    final abs = times.startMinutes + w.startOffsetMinutes + extraMinutes;
    return startOffsetDays + (abs < 0 ? 0 : abs ~/ minutesPerDay);
  }
}

/// 시각 상태 + 영업일 + 경계 → 달력 날짜. 경계를 모르면 호출하지 마라(그때는
/// 날짜를 짐작하지 말고 서버 조립 결과만 보여준다).
ShiftDates resolveShiftDates({
  required DateTime operatingDay,
  required DayStartConfig dayStart,
  required ShiftTimes times,
  /// 사람이 직접 고른 시작 오프셋(0 또는 1). null 이면 자동 판정.
  int? startOffsetOverride,
}) {
  final auto = autoStartOffsetDays(
    operatingDay: operatingDay,
    dayStart: dayStart,
    startMinutes: times.startMinutes,
  );
  return ShiftDates(
    operatingDay: shiftDateOnly(operatingDay),
    autoStartOffsetDays: auto,
    startOffsetDays: startOffsetOverride ?? auto,
    endOffsetFromStartDate: times.endOffsetFromStartDate,
  );
}
