/// Attendance main screen flow orchestrator pure decisions — Phase 5 Stage H-1.
///
/// 새 흐름의 stage 전환 결정 로직:
///   identify → confirm → action → (clock_out: early? → tip) → success
///
/// main screen state machine 에서 호출하는 pure 함수 모음.

import '../models/attendance_action.dart';
import '../providers/attendance_dashboard_provider.dart' show TodayStaffBreak;
import 'minute_time.dart';
import 'staff_status_utils.dart';

/// 현재 시각 기준 scheduled_end 까지 남은 시간 (분).
///   - scheduledEnd null → 0 (no shift)
///   - now > scheduledEnd → 0 (이미 종료 시각 지남)
///   - 그 외 → 분 단위 (소수 버림)
int remainingMinutesUntilScheduledEnd(DateTime? scheduledEnd, DateTime now) {
  if (scheduledEnd == null) return 0;
  if (!scheduledEnd.isAfter(now)) return 0;
  return minutesBetweenClamped(now, scheduledEnd);
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
///   - clock_out 이 아니면 false (그 외 action 은 tip 입력 없음)
///   - 매장 설정 `attendance.tip_entry_enabled` 가 꺼져 있으면 false
///
/// [tipEntryEnabled] 는 DeviceMe 로 내려온 store 설정 해소값이다. 기기 로컬 설정이
/// 아니라서 같은 매장의 모든 기기가 같은 값을 본다.
bool shouldShowTipEntry(AttendanceAction action, {required bool tipEntryEnabled}) {
  if (!tipEntryEnabled) return false;
  return action == AttendanceAction.clockOut;
}

/// Break 사유 입력을 받을지.
///   - break_end 가 아니면 false
///   - 열린 break 정보가 없으면 false (서버가 판단하도록 그대로 보냄)
///   - 허용 시간을 넘겨 서버가 사유를 요구하는 상태면 true
///
/// 이 게이트가 없으면 unpaid_meal 35분 초과 시 서버가 400 을 주는데 사유를 넣을
/// 화면이 없어 휴식을 끝낼 수 없다 (2026-08-08 실사용 버그).
bool shouldShowBreakReasonDialog({
  required AttendanceAction action,
  required TodayStaffBreak? currentBreak,
  required DateTime now,
}) {
  if (action != AttendanceAction.breakEnd) return false;
  if (currentBreak == null) return false;
  // 서버(attendance_device_service)의 break 경과 계산과 같은 규칙(R2)이어야
  // 경계 1분에서 "앱은 모달 안 띄웠는데 서버는 사유 요구" 불일치가 안 생긴다.
  final elapsed = minutesBetweenClamped(currentBreak.startedAt, now);
  final progress = breakProgress(currentBreak.breakType, elapsed);
  return progress.state == BreakState.requiresReason;
}

/// 이 action 이 clock_out 흐름인지 (early/tip 분기 트리거).
bool isClockOutFlow(AttendanceAction action) {
  return action == AttendanceAction.clockOut;
}
