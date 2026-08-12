/// 매니저 모드에서 "지금 보고 있는 영업일"을 다루는 순수 로직 (F5 / D10-1).
///
/// **왜 필요한가.** 키오스크는 오랫동안 오늘 것만 조회했다. 그래서 D10-1(날짜 제약
/// 해제)이 서버에만 열려 있고 화면에서는 다른 날 스케줄을 고를 수조차 없었다.
///
/// **오늘이 아닌 날을 보고 있다는 사실은 반드시 화면에 드러나야 한다.** 매니저가
/// 어제 화면을 오늘로 착각하고 시각을 고치면 잘못된 날의 근태가 바뀐다. 화면 문구는
/// [rosterRelativeLabel] 로 만들고, 그 값이 null 이 아닐 때 강조 표시한다.
///
/// 여기서 말하는 날짜는 **영업일(operating day) 라벨**이지 달력 날짜가 아니다.
/// 기기의 오늘 영업일은 서버가 `device.work_date` 로 내려준다 (store tz + day_start
/// 기준). 로컬에서 계산하지 않는다 — 키오스크엔 day_start 경계 정보가 없다.

/// 시분초를 버린 날짜만. 영업일 비교는 항상 이걸 거친다.
DateTime rosterDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 서버 query param `operating_day` 형식 ("YYYY-MM-DD").
String operatingDayParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Mon, Aug 10" — 화면 전체가 같은 날짜 표기를 쓰도록 여기 하나만 둔다.
String rosterDayLabel(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';

/// [day] 가 [today] 로부터 며칠 떨어져 있는지. 오늘을 모르면 null.
int? rosterDayDelta(DateTime day, DateTime? today) {
  if (today == null) return null;
  return rosterDateOnly(day).difference(rosterDateOnly(today)).inDays;
}

/// 오늘 영업일인가. 오늘을 모르면(work_date 미수신) false 로 본다 —
/// "오늘이라고 단정"하는 쪽이 위험하다.
bool isRosterToday(DateTime day, DateTime? today) => rosterDayDelta(day, today) == 0;

/// 오늘 대비 상대 라벨. **오늘이면 null** — 호출부는 null 을 "강조할 것 없음"으로 쓴다.
///
/// 오늘을 모를 때도 null 이 아니라 'Selected day' 를 준다. 그 경우 우리는 이 날이
/// 오늘인지 아닌지 알 수 없으므로, 아무 표시도 안 하는 것(=오늘처럼 보이는 것)보다
/// "고른 날짜를 보고 있다"고 말해 주는 편이 안전하다.
String? rosterRelativeLabel(DateTime day, DateTime? today) {
  final delta = rosterDayDelta(day, today);
  if (delta == null) return 'Selected day';
  if (delta == 0) return null;
  if (delta == 1) return 'Tomorrow';
  if (delta == -1) return 'Yesterday';
  return delta > 0 ? '+$delta days' : '${-delta} days ago';
}

/// 스케줄 목록 제목. 오늘이면 기존 문구를 그대로 유지한다.
String rosterTitle(DateTime? day, DateTime? today) {
  if (day == null || isRosterToday(day, today)) return "Today's Schedules";
  return 'Schedules · ${rosterDayLabel(day)}';
}

/// 빈 상태 문구 — 어느 날이 비어 있는지 말해 준다.
String rosterEmptyTitle(DateTime? day, DateTime? today) {
  if (day == null || isRosterToday(day, today)) return 'No schedules for today';
  return 'No schedules for ${rosterDayLabel(day)}';
}
