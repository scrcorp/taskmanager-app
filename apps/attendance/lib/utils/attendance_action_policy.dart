/// Attendance action policy — Phase 5 Recovery D.
///
/// today_status × action × current_break × elapsed 매트릭스 분기.
/// ActionSheet 의 _isAllowed / _breakLockedHint 를 pure 함수로 분리.

import '../models/attendance_action.dart';
import 'staff_status_utils.dart';

/// 지금 이 action 이 허용되는지.
///
///   - todayStatus == null → 항상 false (no shift)
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
}) {
  if (todayStatus == null) return false;
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
      return false;
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
