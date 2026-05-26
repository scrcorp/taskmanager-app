/// Store-timezone 시간 표시 helper — Phase 5 Stage K 보강.
///
/// 키오스크는 매장 운영용이라 디바이스 위치와 무관하게 매장 현지 시간으로
/// 표시해야 한다 (한국에서 LA 매장 테스트 시 KST 가 아니라 PDT). 매장 TZ 정보는
/// `attendanceDeviceProvider.device.storeTimezoneOffsetMinutes` 에서 옴.
///
/// 시각 *차이* (break elapsed, remaining minutes 등) 는 timezone 무관하니
/// 본 helper 사용 안 함 — 일반 `DateTime.difference` 그대로.
///
/// 구현 노트:
///   - dart 의 `DateTime` 은 `isUtc` flag + millisSinceEpoch 만 보관.
///     `DateFormat.format` 은 flag 무시하고 wall-clock 값을 그대로 출력함.
///   - 따라서 "UTC 에 offset 분을 더한 DateTime" 을 format 하면 store TZ 의
///     wall-clock 으로 보임 (trick).

/// UTC 시각을 store TZ wall-clock 으로 변환.
///   - offsetMinutes null → utcNow 그대로 (fallback: 키오스크 환경 시간)
///   - offsetMinutes 주어짐 → utc + offset (isUtc=true 유지, 값만 store wall-clock)
DateTime toStoreClock(DateTime utcNow, int? offsetMinutes) {
  if (offsetMinutes == null) return utcNow;
  return utcNow.toUtc().add(Duration(minutes: offsetMinutes));
}
