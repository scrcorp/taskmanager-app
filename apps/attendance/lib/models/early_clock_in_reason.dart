/// Early clock-in override 사유 enum.
///
/// 예정 시작보다 이르게 출근을 강행할 때 server 에 reason 으로 전송한다.
/// 서버는 자유 문자열을 그대로 Activity History 에 남기므로 프리셋은 라벨 텍스트로 보낸다.
/// `other` 일 때만 detail 자유 텍스트가 필요하다.
///
/// 프리셋 문구는 "왜 일찍 왔는가" 전용 — 조기 퇴근/휴식 초과 사유와 다르다.

enum EarlyClockInReason {
  askedToComeEarly,
  coveringForSomeone,
  storeNeedsHelp,
  other,
}

extension EarlyClockInReasonX on EarlyClockInReason {
  /// 서버 기록용 fallback 라벨 (l10n 은 호출 측 책임).
  String get label {
    switch (this) {
      case EarlyClockInReason.askedToComeEarly:
        return 'Asked to come in early';
      case EarlyClockInReason.coveringForSomeone:
        return 'Covering for someone';
      case EarlyClockInReason.storeNeedsHelp:
        return 'Store needs help now';
      case EarlyClockInReason.other:
        return 'Other (please specify)';
    }
  }
}
