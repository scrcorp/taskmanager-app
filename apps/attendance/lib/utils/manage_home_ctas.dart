/// Manage 홈의 CTA 구성 — 헤더 행과 빈 상태 행이 갈라지지 않게 한 곳에서 결정한다.
///
/// 실제 사고: Store Settings 를 헤더 행에만 추가해서, 오늘 스케줄이 0건인 매장
/// (헤더 행이 렌더되지 않는 화면)의 매니저는 매장 설정에 아예 닿지 못했다.
/// 두 화면이 각자 위젯 트리에서 조건을 나열하는 한 같은 누락이 반복된다.
library;

enum ManageHomeCta { addSchedule, staffPins, storeSettings }

/// 권한 플래그로 노출 가능한 CTA 집합. 순서는 각 배치 함수가 정한다.
Set<ManageHomeCta> _available({
  required bool canReadPins,
  required bool canManageStoreSettings,
}) {
  return {
    ManageHomeCta.addSchedule,
    if (canReadPins) ManageHomeCta.staffPins,
    if (canManageStoreSettings) ManageHomeCta.storeSettings,
  };
}

/// 헤더 행 — Add Schedule 이 오른쪽 끝(주 액션)에 오도록 뒤에 둔다.
List<ManageHomeCta> manageHomeHeaderCtas({
  required bool canReadPins,
  required bool canManageStoreSettings,
}) {
  final available = _available(
    canReadPins: canReadPins,
    canManageStoreSettings: canManageStoreSettings,
  );
  return [
    ManageHomeCta.staffPins,
    ManageHomeCta.storeSettings,
    ManageHomeCta.addSchedule,
  ].where(available.contains).toList();
}

/// 빈 상태 행 — Add Schedule 이 첫 행동이라 앞에 둔다.
/// 노출 집합은 헤더와 반드시 동일하다 (순서만 다름).
List<ManageHomeCta> manageHomeEmptyStateCtas({
  required bool canReadPins,
  required bool canManageStoreSettings,
}) {
  final available = _available(
    canReadPins: canReadPins,
    canManageStoreSettings: canManageStoreSettings,
  );
  return [
    ManageHomeCta.addSchedule,
    ManageHomeCta.staffPins,
    ManageHomeCta.storeSettings,
  ].where(available.contains).toList();
}
