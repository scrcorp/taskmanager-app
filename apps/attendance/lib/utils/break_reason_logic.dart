/// BreakReasonDialog pure logic.
///
/// 서버로 보낼 최종 reason 문자열을 만든다. 서버는 자유 문자열을 그대로
/// AttendanceCorrection.reason 에 기록하므로, 프리셋은 라벨 텍스트로 보낸다
/// (콘솔에서 그대로 읽히는 값이어야 한다).

import '../models/break_overrun_reason.dart';

/// Submit 활성 여부.
///   - reason 미선택 → false
///   - other 인데 detail 이 비어있음 → false
bool canSubmitBreakReason(BreakOverrunReason? reason, String detail) {
  if (reason == null) return false;
  if (reason == BreakOverrunReason.other) {
    return detail.trim().isNotEmpty;
  }
  return true;
}

/// 서버 body 의 reason 값.
///   - other → 자유 입력 텍스트
///   - 그 외 → 프리셋 라벨 (영문 고정 — 콘솔에서 읽는 값이라 로케일 따라 흔들리면 안 됨)
String breakReasonToSubmit(BreakOverrunReason reason, String detail) {
  if (reason == BreakOverrunReason.other) return detail.trim();
  return reason.label;
}
