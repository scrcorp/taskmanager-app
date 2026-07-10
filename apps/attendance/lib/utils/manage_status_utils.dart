/// Manage 모드 재설계(Issue 10) — state / anomaly / soon 분류·라벨 헬퍼.
///
/// 상태 모델: clock in/out 은 이벤트, 진짜 state 는 upcoming/working/breaking/done.
///  - anomaly(late/no_show/early_leave/overtime/no_break): server 판정. 액션엔 무관.
///  - soon: anomaly 아님. start_time vs now 로 앱이 자체 판단.
///
/// Pure logic — unit test 로 분기 커버.

import 'staff_status_utils.dart' show StaffSection;

/// state → schedule 3 섹션 분류 (working/breaking=clockedIn, upcoming=notClockedIn, done=completed).
StaffSection sectionForManageState(String state) {
  switch (state) {
    case 'working':
    case 'breaking':
      return StaffSection.clockedIn;
    case 'done':
      return StaffSection.completed;
    case 'upcoming':
      return StaffSection.notClockedIn;
    default:
      return StaffSection.other;
  }
}

/// soon: upcoming 이고 late/no_show 아니며 시작이 now ~ now+threshold 이내.
///
/// startAt(벽시계 datetime, 자정 넘김 시 실제 날짜를 실음)이 있으면 그것으로 직접 비교
/// (오늘 재조립 없이). 없으면 startHHmm 을 오늘 날짜에 합성하는 기존 heuristic.
bool isManageSoon(
  String state,
  List<String> anomalies,
  String? startHHmm,
  DateTime now, {
  int thresholdMinutes = 60,
  DateTime? startAt,
}) {
  if (state != 'upcoming') return false;
  if (anomalies.contains('late') || anomalies.contains('no_show')) return false;
  DateTime? start;
  if (startAt != null) {
    start = startAt;
  } else {
    if (startHHmm == null || !startHHmm.contains(':')) return false;
    final parts = startHHmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    start = DateTime(now.year, now.month, now.day, h, m);
  }
  final diff = start.difference(now).inMinutes;
  return diff >= 0 && diff <= thresholdMinutes;
}

/// state 표시 라벨.
String manageStateLabel(String state) {
  switch (state) {
    case 'upcoming':
      return 'Upcoming';
    case 'working':
      return 'Working';
    case 'breaking':
      return 'Breaking';
    case 'done':
      return 'Done';
    default:
      return state;
  }
}

/// anomaly 표시 라벨.
String manageAnomalyLabel(String anomaly) {
  switch (anomaly) {
    case 'late':
      return 'Late';
    case 'no_show':
      return 'No-show';
    case 'early_leave':
      return 'Early Leave';
    case 'overtime':
      return 'Overtime';
    case 'no_break':
      return 'No Break';
    default:
      return anomaly;
  }
}
