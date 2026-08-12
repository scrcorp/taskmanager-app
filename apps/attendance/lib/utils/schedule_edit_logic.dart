/// 스케줄 시각 편집의 순수 로직 — 시작 / 종료 / 길이 3필드 모델 (정책 D5-2).
///
/// **왜 3필드인가.**
/// 예전에는 시작·종료 2필드에 숨은 플래그(`_startEdited`/`_endEdited`/`_endTouched`)가
/// 붙어 있어서, "사용자가 앞서 무엇을 건드렸는지"에 따라 같은 조작의 결과가 달라졌다.
/// 그 예측 불가능성이 2026-08 스케줄 사고들의 원인 중 하나였다. 지금은 상태가
/// (시작, 길이) 둘뿐이고 **종료는 파생값**이라 숨을 상태 자체가 없다.
///
/// 갱신 규칙(D5-2, 고정):
///   시작 변경 → 길이 유지, 종료가 따라 움직인다 ("시프트를 통째로 옮긴다"가 가장 흔한 의도)
///   종료 변경 → 시작 유지, 길이가 따라 움직인다
///   길이 변경 → 시작 유지, 종료가 따라 움직인다
/// **시작은 어떤 경우에도 저절로 움직이지 않는다.**
///
/// **자정 넘김은 clamp 가 아니라 wrap 이다 (D5-3).**
/// 예전 `clampMinutes(start + length)` 는 25:30 을 23:59 로 잘라버렸고, 23:59 는
/// 5분 배수가 아니라 서버가 거부했다 — 그래서 18:30 이후 시작 스케줄이 저녁마다
/// 생성 실패했다. 하루를 넘으면 잘라내지 말고 **다음 날로 감싼다**. `clampMinutes`
/// 는 휠 입력 범위 제한 전용으로만 남아 있다.

const minutesPerDay = 1440;

/// 스케줄 시각의 최소 단위(분). 서버 `SCHEDULE_STEP_MINUTES` 와 같은 값이어야 한다 —
/// 어긋나면 UI 에서 고를 수 있는 값을 서버가 거부한다. D6: 전 경로 5분 단일.
const scheduleStepMinutes = 5;

/// 신규 스케줄 기본 길이의 **폴백**(5.5h).
///
/// 진짜 출처는 서버 설정 `work.default_schedule_duration_minutes` 다(D8-2).
/// 이제 그 값은 `GET /attendance/me` 응답의 `default_schedule_duration_minutes`
/// 로 내려오고 `DeviceInfo.defaultScheduleDurationMinutes` 에 담긴다.
///
/// **그럼에도 폴백이 남아 있는 이유**: 기기 정보를 아직 못 받은 순간(등록 직후,
/// me 요청 실패 후 재시도 전)에도 모달은 열릴 수 있고, 그때 길이 0 으로 열면
/// 저장이 막혀 매니저가 이유를 알 수 없다. 매장 설정이 없을 때 서버가 쓰는 기본값과
/// **같은 값**이어야 한다 — 다르면 같은 매장에서 화면마다 기본 길이가 달라진다.
const fallbackShiftMinutes = 330;

/// 휴게를 새로 넣을 때의 기본 길이(무급 식사 30분 관례).
const defaultBreakMinutes = 30;

/// 하루를 넘긴 분값을 다음 날 벽시계로 감싼다. 음수도 안전하다(-30 → 23:30).
int wrapMinutes(int n) => ((n % minutesPerDay) + minutesPerDay) % minutesPerDay;

/// 휠 입력 범위 제한 전용 (0..1439).
///
/// **시각 계산에 쓰지 마라.** 자정을 넘는 값을 23:59 로 눌러버려서 (a) 자정 넘김이
/// 사라지고 (b) 23:59 가 5분 배수가 아니라 서버가 거부한다. 계산은 [wrapMinutes].
int clampMinutes(int n) => n < 0 ? 0 : (n > minutesPerDay - 1 ? minutesPerDay - 1 : n);

/// step 배수로 **내림**. 오프셋(길이 기준 상대값) 계산용 — [snapToStep] 은 올림이
/// 섞여 있어 "근무 안에 들어가야 하는" 값에 쓰면 경계를 넘길 수 있다.
int floorToStep(int minutes) =>
    (minutes ~/ scheduleStepMinutes) * scheduleStepMinutes;

/// 분값을 가장 가까운 step 배수로 스냅. 워크인처럼 step 을 벗어난 값을 휠에 올릴 때 사용.
///
/// 상단에서 1440 이 되면 clamp 하지 않고 wrap 한다 — 23:58 을 23:55 로 내리면
/// "가장 가까운 배수"가 아니고, 잘라내기는 [clampMinutes] 주석의 사고를 되풀이한다.
int snapToStep(int minutes) {
  final snapped =
      ((minutes + scheduleStepMinutes ~/ 2) ~/ scheduleStepMinutes) * scheduleStepMinutes;
  return wrapMinutes(snapped);
}

/// "HH:mm" → 분(0..1439). 형식 이상이면 null.
int? hhmmToMinutes(String? hhmm) {
  if (hhmm == null || !hhmm.contains(':')) return null;
  final p = hhmm.split(':');
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String minutesToHHmm(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// 현재 시각을 step 단위로 반올림한 분값.
int round5ToNow(DateTime now) => snapToStep(now.hour * 60 + now.minute);

/// 길이 표시 — "5h 30m" / "45m" / "6h".
String formatDurationLabel(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// 벽시계 + 날짜 오프셋 마커 — "02:00 +1" (D5-1/D5-4).
///
/// 24 초과 표기(`26:00`)는 시스템 전체에서 폐기됐다. 사람이 24를 넘는 시각을 읽으면
/// 헷갈리기 때문이며, 오프셋은 그 모호성 제거 효과를 그대로 주면서 표기는 일상적인
/// 시계 그대로 유지한다. 모든 화면이 **같은** 표기를 써야 한다 — 같은 시각을 두 화면이
/// 다르게 적으면 그 자체가 버그의 씨앗이다.
String hhmmWithDayMarker(int minutes, {int dayOffset = 0}) {
  final hm = minutesToHHmm(wrapMinutes(minutes));
  return dayOffset > 0 ? '$hm +$dayOffset' : hm;
}

/// 벽시계 datetime 이 영업일 라벨보다 며칠 뒤인지 (표시 마커용). 정보가 없으면 0.
///
/// 스케줄은 영업일 창을 넘을 수 있으므로(D4) 오프셋이 2 이상 나올 수도 있다 —
/// 1 로 단정하지 않는다.
int dayOffsetFrom(DateTime? operatingDay, DateTime? at) {
  if (operatingDay == null || at == null) return 0;
  final a = DateTime(operatingDay.year, operatingDay.month, operatingDay.day);
  final b = DateTime(at.year, at.month, at.day);
  final d = b.difference(a).inDays;
  return d > 0 ? d : 0;
}

/// 휴게 창 — **근무 시작 기준 오프셋**으로 들고 있다 (B2/B4).
///
/// 벽시계로 들고 있지 않은 이유가 이 클래스의 존재 이유다. 결정 B2/B4 는
/// "시작을 옮기면 휴게도 같은 오프셋으로 동반 이동"인데, 벽시계로 저장하면 시작이
/// 움직일 때마다 휴게를 다시 계산해야 하고 그 계산을 한 군데라도 빠뜨리면 휴게만
/// 제자리에 남아 근무창 밖으로 밀려난다(= 저장 거부). 오프셋으로 두면 동반 이동이
/// **저절로** 성립한다.
///
/// 서버도 휴게를 자동으로 옮기지 않는다 — 옮기는 계산은 클라이언트 몫이고
/// (서버가 또 옮기면 오프셋이 두 번 적용된다), 그 계산이 바로 이 표현이다.
class BreakWindow {
  /// 근무 시작으로부터 몇 분 뒤에 시작하는가. 음수면 근무 시작 이전이다(= 근무 밖).
  final int startOffsetMinutes;
  final int durationMinutes;

  const BreakWindow({
    required this.startOffsetMinutes,
    required this.durationMinutes,
  });

  @override
  bool operator ==(Object other) =>
      other is BreakWindow &&
      other.startOffsetMinutes == startOffsetMinutes &&
      other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(startOffsetMinutes, durationMinutes);

  @override
  String toString() => 'BreakWindow(+$startOffsetMinutes, $durationMinutes)';
}

/// 편집 중인 시프트의 시각 상태. 불변식은 `종료 = 시작 + 길이` 하나뿐이다.
///
/// [durationMinutes] 는 0 일 수 있다 (사용자가 종료를 시작과 같게 맞추는 도중).
/// 그때는 [isValid] 가 false 가 되고 저장이 막힌다 — 임의로 24시간이나 1분으로
/// 고쳐주지 않는다. 값을 조용히 바꾸면 사용자가 자기가 무엇을 저장했는지 모르게 된다.
class ShiftTimes {
  final int startMinutes; // 0..1439 벽시계
  final int durationMinutes; // 0 이상

  /// 휴게 (없으면 null). 오프셋 표현이라 시작을 옮기면 함께 움직인다.
  final BreakWindow? breakWindow;

  const ShiftTimes({
    required this.startMinutes,
    required this.durationMinutes,
    this.breakWindow,
  });

  /// 시작 + 종료(벽시계)에서 만든다. 종료 ≤ 시작이면 자정을 넘은 것으로 본다.
  ///
  /// 이 추론은 **24시간 미만 시프트에서만** 성립한다. 26시간짜리처럼 그보다 긴
  /// 근무는 벽시계 두 개로 표현할 수 없으므로 [ShiftTimes.fromInstants] 를 쓴다.
  factory ShiftTimes.fromStartEnd(
    int startMinutes,
    int endMinutes, {
    BreakWindow? breakWindow,
  }) =>
      ShiftTimes(
        startMinutes: wrapMinutes(startMinutes),
        durationMinutes: wrapMinutes(endMinutes - startMinutes),
        breakWindow: breakWindow,
      );

  /// 서버가 준 벽시계 datetime 쌍에서 만든다 — 날짜가 붙어 있어 길이가 정확하다.
  /// 24시간 이상이나 자정 넘김을 추론 없이 그대로 살린다.
  factory ShiftTimes.fromInstants(
    DateTime startAt,
    DateTime endAt, {
    BreakWindow? breakWindow,
  }) =>
      ShiftTimes(
        startMinutes: wrapMinutes(startAt.hour * 60 + startAt.minute),
        durationMinutes: endAt.difference(startAt).inMinutes,
        breakWindow: breakWindow,
      );

  int get endMinutes => wrapMinutes(startMinutes + durationMinutes);

  /// 종료가 시작의 며칠 뒤인가 (표시 마커 `+1` 용).
  int get endDayOffset => (startMinutes + durationMinutes) ~/ minutesPerDay;

  bool get isValid => durationMinutes > 0;

  bool get hasBreak => breakWindow != null;

  /// 휴게 시작/종료의 벽시계 분값. 휴게가 없으면 null.
  int? get breakStartMinutes => breakWindow == null
      ? null
      : wrapMinutes(startMinutes + breakWindow!.startOffsetMinutes);

  int? get breakEndMinutes => breakWindow == null
      ? null
      : wrapMinutes(
          startMinutes + breakWindow!.startOffsetMinutes + breakWindow!.durationMinutes);

  /// 휴게 시각의 날짜 오프셋 (`02:00 +1` 표기용). 음수 오프셋은 0 으로 본다 —
  /// 그런 상태는 [breakInsideShift] 가 false 라 이미 화면에서 막힌다.
  int get breakStartDayOffset {
    final w = breakWindow;
    if (w == null) return 0;
    final abs = startMinutes + w.startOffsetMinutes;
    return abs < 0 ? 0 : abs ~/ minutesPerDay;
  }

  int get breakEndDayOffset {
    final w = breakWindow;
    if (w == null) return 0;
    final abs = startMinutes + w.startOffsetMinutes + w.durationMinutes;
    return abs < 0 ? 0 : abs ~/ minutesPerDay;
  }

  /// 휴게가 근무창 안에 있는가. 서버 `BREAK_OUTSIDE_SHIFT` / `BREAK_REVERSED` 와
  /// 같은 판정을 **저장 전에** 화면에서 보여주기 위한 것이다 — 예전엔 휴게 UI 가
  /// 아예 없어서 근무창 밖으로 밀려난 휴게 때문에 저장이 거부돼도 사용자가 그것을
  /// 해소할 방법이 없었다(데드락).
  bool get breakInsideShift {
    final w = breakWindow;
    if (w == null) return true;
    if (w.durationMinutes <= 0) return false;
    if (w.startOffsetMinutes < 0) return false;
    return w.startOffsetMinutes + w.durationMinutes <= durationMinutes;
  }

  /// 저장 가능 상태인가. [isValid] 는 근무 길이만 보므로 휴게까지 포함한 판정은 이것.
  bool get canSave => isValid && breakInsideShift;

  /// 시작 변경 — 길이 유지, 종료가 따라 움직인다. **휴게도 같은 오프셋으로 따라간다**(B2).
  ShiftTimes withStart(int minutes) => ShiftTimes(
        startMinutes: wrapMinutes(minutes),
        durationMinutes: durationMinutes,
        breakWindow: breakWindow,
      );

  /// 종료 변경 — 시작 유지, 길이가 따라 움직인다.
  ///
  /// 24시간 이상 근무를 편집 중이더라도 종료 휠을 건드리면 24시간 미만으로 접힌다.
  /// 벽시계 하나로는 "며칠 뒤 종료"를 표현할 수 없어서이며, 그런 근무는 길이 필드로
  /// 조정해야 한다.
  ///
  /// 휴게는 **건드리지 않는다.** 근무가 짧아져 휴게가 밖으로 나가면 그 사실을
  /// 보여주고 사용자가 옮기거나 지우게 한다 — 조용히 잘라내면 무엇이 저장됐는지
  /// 알 수 없다.
  ShiftTimes withEnd(int minutes) => ShiftTimes(
        startMinutes: startMinutes,
        durationMinutes: wrapMinutes(minutes - startMinutes),
        breakWindow: breakWindow,
      );

  /// 길이 변경 — 시작 유지, 종료가 따라 움직인다.
  ShiftTimes withDuration(int minutes) => ShiftTimes(
        startMinutes: startMinutes,
        durationMinutes: minutes < 0 ? 0 : minutes,
        breakWindow: breakWindow,
      );

  /// 휴게 시작(벽시계) 변경 — 휴게 길이 유지, 휴게 종료가 따라 움직인다.
  /// 근무 시작/종료 규칙과 같은 모양이라 사용자가 규칙을 하나만 기억하면 된다.
  ShiftTimes withBreakStart(int minutes) {
    final len = breakWindow?.durationMinutes ?? defaultBreakMinutes;
    return ShiftTimes(
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      breakWindow: BreakWindow(
        startOffsetMinutes: wrapMinutes(minutes - startMinutes),
        durationMinutes: len,
      ),
    );
  }

  /// 휴게 종료(벽시계) 변경 — 휴게 시작 유지, 휴게 길이가 따라 움직인다.
  /// 휴게가 없으면 아무것도 하지 않는다 (종료만 있는 휴게는 서버가 거부한다).
  ShiftTimes withBreakEnd(int minutes) {
    final w = breakWindow;
    if (w == null) return this;
    final bs = breakStartMinutes!;
    return ShiftTimes(
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      breakWindow: BreakWindow(
        startOffsetMinutes: w.startOffsetMinutes,
        durationMinutes: wrapMinutes(minutes - bs),
      ),
    );
  }

  /// 휴게 추가 — 근무 한가운데에 기본 길이로 넣는다.
  /// 근무가 기본 길이보다 짧으면 근무 전체를 휴게로 두지 않고 **근무 길이만큼** 넣는다
  /// (넣자마자 "근무창 밖" 에러가 뜨면 추가 버튼이 무슨 일을 했는지 알 수 없다).
  ShiftTimes withDefaultBreak() {
    final len = durationMinutes < defaultBreakMinutes ? durationMinutes : defaultBreakMinutes;
    final offset = floorToStep((durationMinutes - len) ~/ 2);
    return ShiftTimes(
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      breakWindow: BreakWindow(
        startOffsetMinutes: offset < 0 ? 0 : offset,
        durationMinutes: len,
      ),
    );
  }

  /// 휴게 삭제 — 저장 시 서버에 `null` 두 개로 나가 "지움"이 된다(B7).
  ShiftTimes withoutBreak() => ShiftTimes(
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is ShiftTimes &&
      other.startMinutes == startMinutes &&
      other.durationMinutes == durationMinutes &&
      other.breakWindow == breakWindow;

  @override
  int get hashCode => Object.hash(startMinutes, durationMinutes, breakWindow);

  @override
  String toString() =>
      'ShiftTimes($startMinutes, +$durationMinutes, break=$breakWindow)';
}

/// 서버가 준 값에서 휴게 오프셋을 복원한다.
///
/// 벽시계 datetime(`break_start_at`)이 있으면 그쪽이 정본 — 날짜가 붙어 있어
/// 자정 넘김이 정확하다. 없으면 HH:mm 두 개로 추론하는데, 이 추론은 휴게가 근무
/// 시작 이후 24시간 안에 있다는 전제에서만 맞다.
BreakWindow? breakWindowFrom({
  DateTime? shiftStartAt,
  DateTime? breakStartAt,
  DateTime? breakEndAt,
  int? shiftStartMinutes,
  int? breakStartMinutes,
  int? breakEndMinutes,
}) {
  if (breakStartAt != null && breakEndAt != null && shiftStartAt != null) {
    return BreakWindow(
      startOffsetMinutes: breakStartAt.difference(shiftStartAt).inMinutes,
      durationMinutes: breakEndAt.difference(breakStartAt).inMinutes,
    );
  }
  if (breakStartMinutes != null && breakEndMinutes != null && shiftStartMinutes != null) {
    return BreakWindow(
      startOffsetMinutes: wrapMinutes(breakStartMinutes - shiftStartMinutes),
      durationMinutes: wrapMinutes(breakEndMinutes - breakStartMinutes),
    );
  }
  // 한쪽만 있는 경우는 휴게 없음으로 본다 — 서버가 짝 규칙(BREAK_PAIR_INCOMPLETE)을
  // 강제하므로 반쪽 값을 화면에 올려 봐야 저장할 수 없다.
  return null;
}
