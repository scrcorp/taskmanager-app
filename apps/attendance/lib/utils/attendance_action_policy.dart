/// Attendance action policy — Phase 5 Recovery D.
///
/// today_status × action × current_break × elapsed 매트릭스 분기.
/// ActionSheet 의 _isAllowed / _breakLockedHint 를 pure 함수로 분리.

import '../models/attendance_action.dart';
import 'staff_status_utils.dart';

/// 지금 이 action 이 허용되는지.
///
///   - todayStatus == null + walkInAllowed=false → 항상 false (no shift)
///   - todayStatus == null + walkInAllowed=true  → Clock In 만 허용 (워크인)
///   - 'upcoming' / 'soon' / 'late' / 'no_show' → Clock In 만
///   - 'working' → Clock Out / 10-min Break / Meal Break
///   - 'on_break':
///       · Clock Out 항상 허용 (긴급)
///       · End Break — break 시간 정책 충족 시만 (paid_10min: 10m+, unpaid_meal: 30m+)
///       · 그 외 false
///   - 'clocked_out' → 전부 false
///   - 기타 → 전부 false
bool isActionAllowed({
  required String? todayStatus,
  required AttendanceAction action,
  String? currentBreakType,
  int currentBreakElapsedMinutes = 0,
  bool walkInAllowed = false,
}) {
  if (todayStatus == null) {
    // 워크인 허용 매장 + 스케줄 없음 → Clock In 만 허용
    return walkInAllowed && action == AttendanceAction.clockIn;
  }
  switch (todayStatus) {
    case 'upcoming':
    case 'soon':
    case 'late':
    case 'no_show':
      return action == AttendanceAction.clockIn;
    case 'working':
      return action == AttendanceAction.clockOut ||
          action == AttendanceAction.breakShortPaid ||
          action == AttendanceAction.breakLongUnpaid;
    case 'on_break':
      if (action == AttendanceAction.clockOut) return true;
      if (action == AttendanceAction.breakEnd) {
        if (currentBreakType == null) return false;
        return breakProgress(currentBreakType, currentBreakElapsedMinutes).canEndBreak;
      }
      return false;
    case 'clocked_out':
      // 워크인 허용 매장이면 퇴근 후 다시 출근(하루 여러 shift) 가능 → Clock In 만 허용.
      return walkInAllowed && action == AttendanceAction.clockIn;
    default:
      return false;
  }
}

/// End Break 가 disabled 일 때 표시할 hint ("Wait Nm more").
/// 활성 가능하거나 break_end 가 아니면 null.
String? breakLockedHint({
  required String? todayStatus,
  required AttendanceAction action,
  String? currentBreakType,
  int currentBreakElapsedMinutes = 0,
}) {
  if (action != AttendanceAction.breakEnd) return null;
  if (todayStatus != 'on_break') return null;
  if (currentBreakType == null) return null;
  final progress = breakProgress(currentBreakType, currentBreakElapsedMinutes);
  if (progress.canEndBreak) return null;
  return 'Wait ${progress.remainingMinutes}m more';
}
