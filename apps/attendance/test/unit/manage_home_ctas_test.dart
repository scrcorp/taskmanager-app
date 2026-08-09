/// Manage 홈 CTA 노출 규칙.
///
/// 이 파일이 존재하는 이유는 실제 사고 때문이다 — Store Settings 를 헤더 행에만
/// 추가해서, 오늘 스케줄이 0건인 매장(헤더 행이 렌더되지 않는 화면)의 매니저는
/// 매장 설정에 아예 닿지 못했다. "두 배치의 노출 집합이 항상 같다" 를 못박는다.
import 'package:attendance/utils/manage_home_ctas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 권한 플래그 4가지 조합 전부.
  const combos = <({bool pins, bool settings})>[
    (pins: false, settings: false),
    (pins: true, settings: false),
    (pins: false, settings: true),
    (pins: true, settings: true),
  ];

  group('노출 집합', () {
    test('권한이 없으면 Add Schedule 만', () {
      expect(
        manageHomeHeaderCtas(canReadPins: false, canManageStoreSettings: false),
        [ManageHomeCta.addSchedule],
      );
      expect(
        manageHomeEmptyStateCtas(
          canReadPins: false,
          canManageStoreSettings: false,
        ),
        [ManageHomeCta.addSchedule],
      );
    });

    test('canReadPins 만 있으면 Staff PINs 만 추가', () {
      final header = manageHomeHeaderCtas(
        canReadPins: true,
        canManageStoreSettings: false,
      );
      expect(header, contains(ManageHomeCta.staffPins));
      expect(header, isNot(contains(ManageHomeCta.storeSettings)));
    });

    test('canManageStoreSettings 만 있으면 Store Settings 만 추가', () {
      final header = manageHomeHeaderCtas(
        canReadPins: false,
        canManageStoreSettings: true,
      );
      expect(header, contains(ManageHomeCta.storeSettings));
      expect(header, isNot(contains(ManageHomeCta.staffPins)));
    });

    test('둘 다 있으면 셋 다', () {
      expect(
        manageHomeHeaderCtas(canReadPins: true, canManageStoreSettings: true)
            .toSet(),
        ManageHomeCta.values.toSet(),
      );
    });
  });

  group('헤더 ↔ 빈 상태 동등성 (회귀 가드)', () {
    for (final c in combos) {
      test('pins=${c.pins}, settings=${c.settings} — 노출 집합이 같다', () {
        final header = manageHomeHeaderCtas(
          canReadPins: c.pins,
          canManageStoreSettings: c.settings,
        );
        final empty = manageHomeEmptyStateCtas(
          canReadPins: c.pins,
          canManageStoreSettings: c.settings,
        );
        expect(empty.toSet(), header.toSet());
        expect(empty.length, header.length, reason: '중복 없이 같은 개수');
      });
    }

    test('스케줄 0건 + 매장설정 권한 있으면 빈 상태에서도 닿는다', () {
      expect(
        manageHomeEmptyStateCtas(
          canReadPins: false,
          canManageStoreSettings: true,
        ),
        contains(ManageHomeCta.storeSettings),
      );
    });
  });

  group('배치 순서', () {
    test('헤더는 Add Schedule 이 마지막 (오른쪽 끝 주 액션)', () {
      final header = manageHomeHeaderCtas(
        canReadPins: true,
        canManageStoreSettings: true,
      );
      expect(header.last, ManageHomeCta.addSchedule);
    });

    test('빈 상태는 Add Schedule 이 처음 (첫 행동)', () {
      final empty = manageHomeEmptyStateCtas(
        canReadPins: true,
        canManageStoreSettings: true,
      );
      expect(empty.first, ManageHomeCta.addSchedule);
    });
  });
}
