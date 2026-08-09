/// EarlyClockInDialog pure logic — 조기 출근 강행 사유.
///
/// break 초과 사유(`break_reason_logic.dart`)와 같은 계약: 서버는 자유 문자열을
/// 그대로 기록하므로 프리셋은 라벨 텍스트로, other 는 사용자가 적은 문장으로 보낸다.

import '../models/early_clock_in_reason.dart';

/// 서버 400 detail 의 code — 이 값일 때만 사유 시트를 띄운다.
/// 메시지 문자열 매칭은 금지 (서버 문구가 바뀌면 조용히 깨진다).
const String kEarlyClockInReasonRequired = 'early_clock_in_reason_required';

/// Submit 활성 여부.
///   - reason 미선택 → false
///   - reason = other AND detail.trim() 비어있음 → false
///   - 그 외 → true
bool canSubmitEarlyClockIn(EarlyClockInReason? reason, String detail) {
  if (reason == null) return false;
  if (reason == EarlyClockInReason.other) {
    return detail.trim().isNotEmpty;
  }
  return true;
}

/// 서버 body 의 reason 값. other 면 사용자가 적은 문장, 아니면 프리셋 라벨.
String earlyClockInReasonToSubmit(EarlyClockInReason reason, String detail) {
  if (reason == EarlyClockInReason.other) return detail.trim();
  return reason.label;
}

/// "예정보다 얼마나 이른가" 표시 ("2h 5m" / "45m").
///
/// 상한이 없어서 몇 시간 전 출근도 통과한다 — 얼마나 이른지 크게 보여주는 게
/// 오조작(다음날 shift 선택 등)을 막는 유일한 장치다.
String formatEarlyBy(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// 서버 detail 에서 minutes_early 를 안전하게 꺼낸다 (없거나 형식 이상 → 0).
int minutesEarlyFromDetail(Map<String, dynamic>? detail) {
  final raw = detail?['minutes_early'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
