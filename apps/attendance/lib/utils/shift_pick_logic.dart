/// shift 선택 · 겹침 clock-in pure logic (계약 §1 / §3, 페이즈 ④⑤).
///
/// **이 파일은 판정을 하지 않는다.** "지금 고르면 몇 분 지각인가" 는 서버가 계산해
/// `clock_in_preview` 로 내려준다(R0-1). 여기 있는 건 선택 규칙과 표시 형태뿐이다.
///
/// 앱이 프리뷰를 자체 계산하면 초 버림 지점이 하나 더 생겨 화면과 기록이 갈린다 —
/// 원인 A 를 고치겠다고 만든 화면이 새 불일치를 만드는 셈이 된다.
library;

import '../models/identify_response.dart';

/// 겹침 clock-in 확인 요구 (계약 §3.2). `allow_overlap: true` 로 재전송한다.
const String kOverlappingClockInConfirmationRequired =
    'overlapping_clock_in_confirmation_required';

/// `early_clock_in_requested_by` 가 서버 목록 규칙을 통과 못했다 (계약 §5).
/// 앱은 id 를 떼고 **1회 자동 재시도** 한다 — 키오스크에서 출근이 막히면 안 된다.
const String kInvalidReasonUser = 'invalid_reason_user';

/// 명시 선택한 schedule 이 더 이상 후보가 아니다 (계약 §5).
const String kShiftNotAvailable = 'shift_not_available';

/// identify 프리뷰의 신선도 상한 (계약 §1.2).
///
/// picker 를 열어둔 채 시간이 흐르면 "12m late" 가 낡는다. 이 시간을 넘겨 제출하면
/// identify 를 다시 부른 뒤 보낸다. **판정에 쓰지 않는다** — 어디까지나 재조회 트리거다.
const Duration kPreviewFreshness = Duration(minutes: 3);

/// 못 고르는 이유 — 서버 `ineligible_reason` (계약 §1.5).
const String kIneligibleAlreadyCompleted = 'already_completed';
const String kIneligibleAlreadyClockedIn = 'already_clocked_in';

/// 시작이 자기 영업일 구간 밖인 스케줄 (2026-08-19). 목록에서 **지우지 않는다** —
/// 그 shift 를 기다리던 사람에게 "없다" 가 아니라 "이건 고쳐야 한다" 를 보여야 한다.
const String kIneligibleOutsideOperatingWindow = 'outside_operating_window';

/// 프리뷰 표시 종류. 서버 `kind` 문자열을 화면이 다루기 쉬운 형태로만 옮긴다.
enum ShiftPreviewKind { early, onTime, late, unknown }

/// 서버 `clock_in_preview` → (표시 종류, 분).
///
/// [minutes] 는 항상 0 이상이다. unknown/onTime 이면 0.
({ShiftPreviewKind kind, int minutes}) shiftPreviewOf(ClockInPreview? preview) {
  if (preview == null) return (kind: ShiftPreviewKind.unknown, minutes: 0);
  switch (preview.kind) {
    case 'early':
      return (
        kind: ShiftPreviewKind.early,
        minutes: preview.minutesEarly < 0 ? 0 : preview.minutesEarly,
      );
    case 'late':
      return (
        kind: ShiftPreviewKind.late,
        minutes: preview.minutesLate < 0 ? 0 : preview.minutesLate,
      );
    case 'on_time':
      return (kind: ShiftPreviewKind.onTime, minutes: 0);
    default:
      return (kind: ShiftPreviewKind.unknown, minutes: 0);
  }
}

/// "3h 12m" / "3h" / "12m" — 숫자를 앞에 둔다.
///
/// 라벨(`late` / `early`)은 l10n 이 뒤에 붙인다. 목록에서 숫자가 먼저 눈에 들어와야
/// 오선택을 막는다(계약 §1.4).
String formatShiftDuration(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '${h}h' : '${h}h ${rest}m';
}

/// 앱이 기본으로 다룰 shift (계약 §1.7).
///
/// 1) 서버 `default_schedule_id` 와 같은 항목
/// 2) 없으면 항목의 `is_default`
/// 3) 그래도 없으면 고를 수 있는 첫 항목 (구버전 서버 대비)
/// 4) 그것도 없으면 목록의 첫 항목
///
/// 앱이 스스로 "가장 가까운 미래" 같은 규칙을 만들지 않는다 — 그 규칙이 갈린 것이
/// 원인 A 였다. 서버가 정한 값을 그대로 쓰고, 없을 때만 순서대로 물러선다.
TodayAttendanceItem? pickDefaultShift(IdentifyResponse resp) {
  final items = resp.todayAttendances;
  if (items.isEmpty) return null;

  final defaultId = resp.defaultScheduleId;
  if (defaultId != null && defaultId.isNotEmpty) {
    for (final item in items) {
      if (item.scheduleId == defaultId) return item;
    }
  }
  for (final item in items) {
    if (item.isDefault) return item;
  }
  for (final item in items) {
    if (item.clockInEligible) return item;
  }
  return items.first;
}

/// "이거 아님" 버튼을 낼지 — 후보가 2개 이상일 때만 (D1/D14).
///
/// 1개뿐이면 바꿀 대상이 없다. 목록을 먼저 띄우지 않는 것과 같은 이유로,
/// 정상 출근자에게 선택지를 만들어 탭을 늘리지 않는다.
bool canChooseShift(IdentifyResponse resp) => resp.todayAttendances.length >= 2;

/// 이 항목을 clock-in 대상으로 고를 수 있는가.
bool isShiftSelectable(TodayAttendanceItem item) => item.clockInEligible;

/// 겹쳐 열린 shift 가 하나라도 있는가 (계약 §3.4 배너 트리거).
///
/// 해소될 때까지 매 PIN 식별 화면에 배너를 띄운다. 성공 직후 한 번만 보여주면
/// 교대가 끝날 때까지 아무도 모른다.
bool hasOverlappingShift(IdentifyResponse resp) =>
    resp.todayAttendances.any((item) => item.overlapping);

/// clock action 200 응답이 "겹쳐서 찍혔다" 를 알리는가 (계약 §3.4).
///
/// 트리거는 `overlap.is_overlapping` 하나뿐이다. 표시 문구는 서버가 내려보내지
/// 않는다(R0-3) — 문구는 앱 l10n 소유.
bool isOverlappingClockInResponse(Map<String, dynamic>? data) {
  final overlap = data?['overlap'];
  if (overlap is! Map) return false;
  return overlap['is_overlapping'] == true;
}

/// identify 로 받은 프리뷰가 낡았는가 (계약 §1.2).
///
/// [identifiedAt] 은 응답을 **받은 로컬 시각**이다. 서버 시각을 로컬 시계와 빼면
/// 기기 시계 오차가 그대로 섞인다 — 여기서 재는 건 "화면을 얼마나 오래 열어뒀나" 다.
bool isPreviewStale({DateTime? identifiedAt, required DateTime now}) {
  if (identifiedAt == null) return false;
  final elapsed = now.difference(identifiedAt);
  return elapsed > kPreviewFreshness;
}

/// 겹침 확인 400 detail 에서 "열린 shift" 시간대를 뽑는다 (안내 문구 조립용).
///
/// 없으면 null — 앱은 시간대 없이 일반 문구만 보여준다.
({String start, String end})? openShiftWindowFromDetail(
  Map<String, dynamic>? detail,
) {
  final start = detail?['open_scheduled_start_display'];
  final end = detail?['open_scheduled_end_display'];
  if (start is String && start.isNotEmpty && end is String && end.isNotEmpty) {
    return (start: start, end: end);
  }
  return null;
}

/// 이 항목이 "어제 영업일" shift 인가 (D4).
///
/// [today] 는 기기가 보는 영업일 라벨("YYYY-MM-DD", DeviceInfo.workDate).
/// 둘 중 하나라도 없으면 판단하지 않는다 — 모르면 배지를 안 붙이는 쪽이 안전하다.
bool isPreviousOperatingDay(TodayAttendanceItem item, String? today) {
  final day = item.operatingDay;
  if (day == null || day.isEmpty) return false;
  if (today == null || today.isEmpty) return false;
  return day != today;
}
