/// IdentityConfirmDialog pure logic — Phase 5 Recovery C.
///
/// today_status 기반 분기와 이름 → 이니셜 변환을 widget 에서 분리.

/// Close 버튼만 보여줄 상태인지.
///   - null + walkInAllowed=false → true (NO SHIFT TODAY, 차단)
///   - null + walkInAllowed=true  → false (워크인 클락인 허용 — Yes + Close)
///   - 'clocked_out' + walkInAllowed=false → true (Shift completed, 차단)
///   - 'clocked_out' + walkInAllowed=true  → false (퇴근 후 재출근 허용 — 하루 여러 워크인 shift)
///   - 그 외 (working/on_break/upcoming/soon/late/no_show 등) → false (Yes + Close)
bool isCloseOnly(String? todayStatus, {bool walkInAllowed = false}) {
  if (todayStatus == null) return !walkInAllowed;
  if (todayStatus == 'clocked_out') return !walkInAllowed;
  return false;
}

/// status 별 dialog 표시용 라벨.
///   - working → 'Currently working'
///   - on_break → 'On break'
///   - upcoming → 'Shift upcoming'
///   - soon → 'Shift starting soon'
///   - late → 'Running late'
///   - no_show → 'No-show'
///   - clocked_out → 'Shift completed'
///   - 그 외 → status 그대로 반환
String labelForStatus(String status) {
  switch (status) {
    case 'working':
      return 'Currently working';
    case 'on_break':
      return 'On break';
    case 'upcoming':
      return 'Shift upcoming';
    case 'soon':
      return 'Shift starting soon';
    case 'late':
      return 'Running late';
    case 'no_show':
      return 'No-show';
    case 'clocked_out':
      return 'Shift completed';
    default:
      return status;
  }
}

/// 이름 → 이니셜 (대문자 최대 2글자).
///   - '' → '?'
///   - 'Marcus' → 'M'
///   - 'Marcus Lee' → 'ML'
///   - 'Marcus Lee Junior' → 'ML' (앞 2단어만)
///   - 공백 여러 개 → 단어로 split
String initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.take(2).map((p) => p[0]).join().toUpperCase();
}
