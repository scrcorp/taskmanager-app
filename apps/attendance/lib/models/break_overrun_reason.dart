/// Break 초과 사유 enum.
///
/// 허용 시간을 넘긴 break 를 끝낼 때 server 에 reason 필드로 전송한다
/// (unpaid_meal 35분 이상이면 서버가 필수로 요구).
/// 프리셋은 "왜 늦게 끝났는가" 전용 — early clock-out 사유와 성격이 다르다.
/// `other` 일 때만 자유 텍스트가 필요하다.

enum BreakOverrunReason {
  forgotToEnd,
  managerApproved,
  personalEmergency,
  waitingForCoverage,
  other,
}

extension BreakOverrunReasonX on BreakOverrunReason {
  /// 서버에 전달할 key (스네이크 케이스 string).
  String get apiKey {
    switch (this) {
      case BreakOverrunReason.forgotToEnd:
        return 'forgot_to_end';
      case BreakOverrunReason.managerApproved:
        return 'manager_approved';
      case BreakOverrunReason.personalEmergency:
        return 'personal_emergency';
      case BreakOverrunReason.waitingForCoverage:
        return 'waiting_for_coverage';
      case BreakOverrunReason.other:
        return 'other';
    }
  }

  /// UI 표시 라벨 (fallback 영어). l10n 은 호출 측 책임.
  String get label {
    switch (this) {
      case BreakOverrunReason.forgotToEnd:
        return 'Forgot to end break';
      case BreakOverrunReason.managerApproved:
        return 'Manager approved longer break';
      case BreakOverrunReason.personalEmergency:
        return 'Personal emergency';
      case BreakOverrunReason.waitingForCoverage:
        return 'Waiting for coverage';
      case BreakOverrunReason.other:
        return 'Other (please specify)';
    }
  }
}
