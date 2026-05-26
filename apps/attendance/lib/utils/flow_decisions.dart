/// Attendance main screen flow orchestrator pure decisions — Phase 5 Stage H-1.
///
/// 새 흐름의 stage 전환 결정 로직:
///   identify → confirm → action → (clock_out: early? → tip) → success
///
/// main screen state machine 에서 호출하는 pure 함수 모음.

import '../models/attendance_action.dart';

/// 현재 시각 기준 scheduled_end 까지 남은 시간 (분).
///   - scheduledEnd null → 0 (no shift)
///   - now > scheduledEnd → 0 (이미 종료 시각 지남)
///   - 그 외 → 분 단위 (소수 버림)
int remainingMinutesUntilScheduledEnd(DateTime? scheduledEnd, DateTime now) {
  if (scheduledEnd == null) return 0;
  if (!scheduledEnd.isAfter(now)) return 0;
  return scheduledEnd.difference(now).inMinutes;
}

/// Early clock-out reason picker 를 띄울지.
///   - action != clockOut → false
///   - scheduledEnd null → false (no shift 면 일반 clock-out 안 함)
///   - 남은 시간 <= threshold → false (정상 퇴근)
///   - 남은 시간 > threshold → true
///
/// threshold 기본값 5분 (scheduled_end 보다 5분 초과로 일찍 가는 경우 사유 요구).
bool shouldShowEarlyClockOutDialog({
  required AttendanceAction action,
  required DateTime? scheduledEnd,
  required DateTime now,
  int thresholdMinutes = 5,
}) {
  if (action != AttendanceAction.clockOut) return false;
  if (scheduledEnd == null) return false;
  final remaining = remainingMinutesUntilScheduledEnd(scheduledEnd, now);
  return remaining > thresholdMinutes;
}

/// Tip entry dialog 를 띄울지.
///   - clock_out 일 때만 true (그 외 action 은 tip 입력 없음)
bool shouldShowTipEntry(AttendanceAction action) {
  return action == AttendanceAction.clockOut;
}

/// 이 action 이 clock_out 흐름인지 (early/tip 분기 트리거).
bool isClockOutFlow(AttendanceAction action) {
  return action == AttendanceAction.clockOut;
}
