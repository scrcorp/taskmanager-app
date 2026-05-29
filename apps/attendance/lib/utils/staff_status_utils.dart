/// Staff status / break 정책 helper — Phase 5 Schedule screen + dialog 공유.
///
/// Pure logic (DB/IO 없음). unit test 로 전 분기 커버.

import '../providers/attendance_dashboard_provider.dart';

/// Schedule screen 의 3 섹션 분류 키. (Issue 9: onShift → clockedIn 라벨 변경)
enum StaffSection { clockedIn, notClockedIn, completed, other }

StaffSection classifySection(String status) {
  switch (status) {
    case 'working':
    case 'on_break':
      return StaffSection.clockedIn;
    case 'upcoming':
    case 'soon':
    case 'late':
    case 'no_show':
      return StaffSection.notClockedIn;
    case 'clocked_out':
      return StaffSection.completed;
    default:
      return StaffSection.other; // cancelled 등
  }
}

/// status 라벨 (UI 표시용).
String statusLabel(String status) {
  switch (status) {
    case 'working':
      return 'Working';
    case 'on_break':
      return 'On Break';
    case 'upcoming':
      return 'Upcoming';
    case 'soon':
      return 'Soon';
    case 'late':
      return 'Late';
    case 'no_show':
      return 'No-show';
    case 'clocked_out':
      return 'Clocked Out';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

/// break_type 라벨.
String breakLabel(String breakType) {
  // 신규 (paid_10min/unpaid_meal) + 레거시 (paid_short/unpaid_long) dual-read
  if (breakType == 'unpaid_meal' || breakType == 'unpaid_long') {
    return 'Meal Break (unpaid)';
  }
  if (breakType == 'paid_10min' || breakType == 'paid_short') {
    return '10-min Break (paid)';
  }
  return 'On Break';
}

/// StaffBlock 의 1줄 서브 텍스트. 상태별로 가장 유용한 정보 한 가지.
String staffBlockSubline(TodayStaffRow row, {DateTime? now}) {
  final n = now ?? DateTime.now();
  switch (row.status) {
    case 'working':
      return row.clockInDisplay != null ? 'In ${row.clockInDisplay}' : 'Working';
    case 'on_break':
      final br = row.currentBreak;
      if (br != null) {
        final mins = n.difference(br.startedAt).inMinutes;
        return 'Break ${mins}m';
      }
      return 'On Break';
    case 'clocked_out':
      return row.clockOutDisplay != null ? 'Out ${row.clockOutDisplay}' : 'Clocked Out';
    default:
      return row.scheduledStartDisplay ?? '—';
  }
}

/// Break 정책 분석.
///   - paid_10min: 10m 미만 → End Break 불가. 10m 초과 → 초과분 unpaid (over_allowance).
///   - unpaid_meal: 30m 미만 → End Break 불가. 30~35m within. 35m 이상 → 사유 필요 (requires_reason).
class BreakProgress {
  final int elapsedMinutes;
  final BreakState state;
  final String hint;
  final bool canEndBreak;
  final int remainingMinutes;

  const BreakProgress({
    required this.elapsedMinutes,
    required this.state,
    required this.hint,
    required this.canEndBreak,
    required this.remainingMinutes,
  });
}

enum BreakState { tooShort, within, overAllowance, requiresReason }

BreakProgress breakProgress(String breakType, int elapsedMinutes) {
  final isPaid = breakType == 'paid_10min' || breakType == 'paid_short';

  if (isPaid) {
    if (elapsedMinutes < 10) {
      return BreakProgress(
        elapsedMinutes: elapsedMinutes,
        state: BreakState.tooShort,
        hint: 'End Break available after ${10 - elapsedMinutes}m more (10m minimum).',
        canEndBreak: false,
        remainingMinutes: 10 - elapsedMinutes,
      );
    }
    if (elapsedMinutes == 10) {
      return const BreakProgress(
        elapsedMinutes: 10,
        state: BreakState.within,
        hint: 'Paid up to 10m. You can end break now.',
        canEndBreak: true,
        remainingMinutes: 0,
      );
    }
    return BreakProgress(
      elapsedMinutes: elapsedMinutes,
      state: BreakState.overAllowance,
      hint: 'Excess ${elapsedMinutes - 10}m will be unpaid.',
      canEndBreak: true,
      remainingMinutes: 0,
    );
  }

  // unpaid_meal
  if (elapsedMinutes < 30) {
    return BreakProgress(
      elapsedMinutes: elapsedMinutes,
      state: BreakState.tooShort,
      hint: 'End Break available after ${30 - elapsedMinutes}m more (30m minimum).',
      canEndBreak: false,
      remainingMinutes: 30 - elapsedMinutes,
    );
  }
  if (elapsedMinutes < 35) {
    return BreakProgress(
      elapsedMinutes: elapsedMinutes,
      state: BreakState.within,
      hint: 'Within allowance (30~35m). You can end break now.',
      canEndBreak: true,
      remainingMinutes: 0,
    );
  }
  return BreakProgress(
    elapsedMinutes: elapsedMinutes,
    state: BreakState.requiresReason,
    hint: 'Over 35m — reason required to end break.',
    canEndBreak: true,
    remainingMinutes: 0,
  );
}
