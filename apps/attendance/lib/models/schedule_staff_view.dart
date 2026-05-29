/// 공용 표시 모델 (Issue 10 통합) — staff schedule / manage 홈이 같은 카드·패널을
/// 쓰도록, 서로 다른 두 행(TodayStaffRow / AdminScheduleRow)을 이 뷰로 변환한다.
///
/// 시각은 모두 store tz "HH:mm" 문자열 (서버 포매팅). break 는 공용 ManageBreak 재사용.

import '../providers/attendance_dashboard_provider.dart' show TodayStaffRow;
import '../providers/attendance_manage_provider.dart' show AdminScheduleRow, ManageBreak;

class ScheduleStaffView {
  final String id; // 선택 키 (scheduleId 우선, 없으면 userId)
  final String name;
  final String? roleLabel; // "Open · Server" (없으면 null)
  final String state; // upcoming | working | breaking | done
  final List<String> anomalies; // late/no_show/early_leave/overtime/no_break
  final List<ManageBreak> breaks;
  final String? scheduledStart; // "HH:mm"
  final String? scheduledEnd;
  final String? clockIn; // "HH:mm"
  final String? clockOut;

  const ScheduleStaffView({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.state,
    required this.anomalies,
    required this.breaks,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.clockIn,
    required this.clockOut,
  });
}

extension AdminScheduleRowView on AdminScheduleRow {
  ScheduleStaffView toView() => ScheduleStaffView(
        id: scheduleId,
        name: userName,
        roleLabel: workRoleLabel,
        state: state,
        anomalies: anomalies,
        breaks: breaks,
        scheduledStart: startHHmm,
        scheduledEnd: endHHmm,
        clockIn: clockInDisplay,
        clockOut: clockOutDisplay,
      );
}

extension TodayStaffRowView on TodayStaffRow {
  ScheduleStaffView toView() => ScheduleStaffView(
        id: scheduleId ?? userId,
        name: userName,
        roleLabel: null,
        state: state,
        anomalies: anomalies,
        breaks: breaks,
        scheduledStart: scheduledStartDisplay,
        scheduledEnd: scheduledEndDisplay,
        clockIn: clockInDisplay,
        clockOut: clockOutDisplay,
      );
}
