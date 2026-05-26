/// EarlyClockOutDialog pure logic — Phase 5 Recovery E.

import '../models/early_clock_out_reason.dart';

/// Submit 활성 여부.
///   - reason 미선택 → false
///   - reason = other AND detail.trim() 비어있음 → false
///   - 그 외 → true
bool canSubmitEarlyClockOut(EarlyClockOutReason? reason, String detail) {
  if (reason == null) return false;
  if (reason == EarlyClockOutReason.other) {
    return detail.trim().isNotEmpty;
  }
  return true;
}

/// 분 단위 잔여 시간 표시 ("4h 30m" / "45m" / "1h 0m").
///   - 60 미만 → "${m}m"
///   - 60 이상 → "${h}h ${m}m"
///   - 음수 → "0m"
String formatRemainingMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Submit 시 server 에 보낼 detail 값 (other 외엔 null, other 면 trimmed detail).
String? detailToSubmit(EarlyClockOutReason reason, String detail) {
  if (reason != EarlyClockOutReason.other) return null;
  return detail.trim();
}
