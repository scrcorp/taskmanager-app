/// Early clock-out 사유 enum.
///
/// 사용자가 scheduled_end 전에 clock-out 시 server 에 reason 필드로 전송.
/// `other` 일 때만 detail 자유 텍스트 필요.

enum EarlyClockOutReason {
  feelingUnwell,
  familyEmergency,
  managerApproved,
  personal,
  other,
}

extension EarlyClockOutReasonX on EarlyClockOutReason {
  /// 서버에 전달할 key (스네이크 케이스 string).
  String get apiKey {
    switch (this) {
      case EarlyClockOutReason.feelingUnwell:
        return 'feeling_unwell';
      case EarlyClockOutReason.familyEmergency:
        return 'family_emergency';
      case EarlyClockOutReason.managerApproved:
        return 'manager_approved';
      case EarlyClockOutReason.personal:
        return 'personal';
      case EarlyClockOutReason.other:
        return 'other';
    }
  }

  /// UI 표시 라벨 (fallback 영어). l10n 은 호출 측 책임.
  String get label {
    switch (this) {
      case EarlyClockOutReason.feelingUnwell:
        return 'Feeling unwell';
      case EarlyClockOutReason.familyEmergency:
        return 'Family emergency';
      case EarlyClockOutReason.managerApproved:
        return 'Manager approved';
      case EarlyClockOutReason.personal:
        return 'Personal reason';
      case EarlyClockOutReason.other:
        return 'Other (please specify)';
    }
  }
}
