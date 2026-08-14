/// EarlyClockInDialog pure logic — 조기 출근 강행 사유.
///
/// break 초과 사유(`break_reason_logic.dart`)와 같은 계약: 서버는 자유 문자열을
/// 그대로 기록하므로 프리셋은 라벨 텍스트로, other 는 사용자가 적은 문장으로 보낸다.
///
/// 2026-08-13(D8~D10): "Asked to come in early" 만 **누가 불렀는지**를 함께 받는다.
/// 문자열(`Asked to come in early (John Kim)`)과 user_id 를 둘 다 남긴다 —
/// 문자열만 남기면 동명이인 구분·개명 추적·요청자별 집계가 전부 불가능하고
/// 나중에 소급해서 채울 수 없다(D9).

import '../models/early_clock_in_reason.dart';

/// 서버 400 detail 의 code — 이 값일 때만 사유 시트를 띄운다.
/// 메시지 문자열 매칭은 금지 (서버 문구가 바뀌면 조용히 깨진다).
const String kEarlyClockInReasonRequired = 'early_clock_in_reason_required';

/// "직접 입력" 이름 최대 길이 (계약 §2.2).
const int kEarlyRequesterNameMaxLength = 60;

/// 조기 출근을 요청한 사람.
///
/// [userId] 는 매장 Manager/SV 목록에서 고른 경우에만 있다.
/// "직접 입력"(명단 밖 사람 — 다른 매장 매니저, 본사 등)은 id 자체가 없으므로 null.
class EarlyRequester {
  final String? userId;
  final String name;

  const EarlyRequester({required this.name, this.userId});

  /// id 를 뗀 사본 — 서버가 `invalid_reason_user` 로 거부했을 때의 1회 재시도용.
  EarlyRequester get withoutId => EarlyRequester(name: name);
}

/// Submit 활성 여부.
///   - reason 미선택 → false
///   - reason = other AND detail.trim() 비어있음 → false
///   - reason = askedToComeEarly AND 요청자 미지정 → false
///   - 그 외 → true
///
/// 요청자를 필수로 두는 이유: 이 항목의 존재 이유가 "확인하는 매니저가 누구에게
/// 물어야 할지" 이기 때문이다. 비워두면 예전과 똑같은 문자열이 남는다.
/// 목록이 비어 있어도 "직접 입력" 이 **상시** 열려 있어 현장에서 막히지 않는다.
bool canSubmitEarlyClockIn(
  EarlyClockInReason? reason,
  String detail, {
  EarlyRequester? requester,
}) {
  if (reason == null) return false;
  if (reason == EarlyClockInReason.other) {
    return detail.trim().isNotEmpty;
  }
  if (reason == EarlyClockInReason.askedToComeEarly) {
    return requester != null && requester.name.trim().isNotEmpty;
  }
  return true;
}

/// 서버 body 의 reason 값. **항상 영어**다 (로케일별로 갈리면 콘솔 집계가 두 벌이 된다).
///   - other                → 사용자가 적은 문장
///   - askedToComeEarly     → `Asked to come in early (John Kim)`
///   - 그 외 프리셋          → 라벨 그대로 (대상자를 붙이지 않는다, D10)
String earlyClockInReasonToSubmit(
  EarlyClockInReason reason,
  String detail, {
  EarlyRequester? requester,
}) {
  if (reason == EarlyClockInReason.other) return detail.trim();
  if (reason == EarlyClockInReason.askedToComeEarly) {
    final name = requester?.name.trim() ?? '';
    if (name.isNotEmpty) return '${reason.label} ($name)';
  }
  return reason.label;
}

/// 이 사유에 요청자(user_id)를 실어 보내는가.
///
/// D10 이 범위를 early clock-in 의 "불려서 왔다" 하나로 좁혔다. 다른 프리셋에
/// id 를 붙이면 서버가 조용히 무시하고, 그 사실을 아무도 모른 채 집계가 빈다.
String? earlyClockInRequestedBy(
  EarlyClockInReason reason, {
  EarlyRequester? requester,
}) {
  if (reason != EarlyClockInReason.askedToComeEarly) return null;
  final id = requester?.userId;
  return (id != null && id.isNotEmpty) ? id : null;
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
