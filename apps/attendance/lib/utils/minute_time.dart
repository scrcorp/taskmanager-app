/// 분 단위 절삭 규칙(R1/R2) 헬퍼.
///
/// 기록(서버 DB)은 초까지 보존하되, **표시와 계산은 모두 분 단위**로 하고 초는 무시한다.
/// 핵심은 "차이를 내림"이 아니라 **"각 시각을 분으로 절삭한 뒤 차이"** 라는 점이다.
/// 화면에 보이는 `HH:MM` 끼리의 뺄셈과 지표가 항상 일치해야 하기 때문.
///
/// 예) 22:26:50 → 22:57:20
///   - `Duration.inMinutes` (차이 내림) = 30
///   - 절삭 후 차이 (본 헬퍼)          = 31  ← 화면 `22:26 – 22:57` 과 일치
///
/// 서버 `app/utils/timezone.py: minutes_between`,
/// 콘솔 `src/lib/utils.ts: minutesBetween` 과 동일 규칙.
library;

/// 초·밀리초·마이크로초를 버려 분 경계로 절삭.
DateTime floorToMinute(DateTime value) {
  return DateTime.fromMillisecondsSinceEpoch(
    (value.millisecondsSinceEpoch ~/ 60000) * 60000,
    isUtc: value.isUtc,
  );
}

/// 두 시각 사이의 분 — 각각 분 절삭한 뒤 차이 (R2).
///
/// 음수도 그대로 반환한다 (자정 wrap 등 호출 측 처리가 필요한 경우가 있음).
/// 0 하한이 필요하면 [minutesBetweenClamped] 를 쓴다.
int minutesBetween(DateTime start, DateTime end) {
  return floorToMinute(end).difference(floorToMinute(start)).inMinutes;
}

/// [minutesBetween] 의 0 하한 버전 — 경과 시간 표시용.
int minutesBetweenClamped(DateTime start, DateTime end) {
  final m = minutesBetween(start, end);
  return m > 0 ? m : 0;
}
