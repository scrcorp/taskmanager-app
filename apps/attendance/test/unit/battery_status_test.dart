/// BatteryStatus 파싱/파생상태 unit tests.
///
/// 네이티브에서 오는 map 은 신뢰할 수 없는 입력으로 다룬다 — 필드가 빠지거나
/// 타입이 달라도 헤더가 죽으면 안 되므로 전 분기를 고정한다.

import 'package:attendance/models/battery_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BatteryStatus.fromMap', () {
    test('정상 map → 그대로 파싱', () {
      final s = BatteryStatus.fromMap(const {
        'level': 85,
        'charging': true,
        'full': false,
        'plugged': true,
      });
      expect(s.level, 85);
      expect(s.charging, isTrue);
      expect(s.full, isFalse);
      expect(s.plugged, isTrue);
    });

    test('level -1 (네이티브의 unknown) → null', () {
      final s = BatteryStatus.fromMap(const {'level': -1});
      expect(s.level, isNull);
    });

    test('level 이 범위를 벗어나면 null', () {
      expect(BatteryStatus.fromMap(const {'level': 101}).level, isNull);
      expect(BatteryStatus.fromMap(const {'level': -5}).level, isNull);
    });

    test('level 0 / 100 은 유효값', () {
      expect(BatteryStatus.fromMap(const {'level': 0}).level, 0);
      expect(BatteryStatus.fromMap(const {'level': 100}).level, 100);
    });

    test('키가 통째로 없으면 기본값 (level null, 플래그 전부 false)', () {
      final s = BatteryStatus.fromMap(const {});
      expect(s.level, isNull);
      expect(s.charging, isFalse);
      expect(s.full, isFalse);
      expect(s.plugged, isFalse);
    });

    test('타입이 다른 값이 와도 던지지 않고 안전한 기본값', () {
      final s = BatteryStatus.fromMap(const {
        'level': '85',
        'charging': 1,
        'plugged': 'yes',
      });
      expect(s.level, isNull);
      expect(s.charging, isFalse);
      expect(s.plugged, isFalse);
    });
  });

  group('powered', () {
    test('충전 중이면 true', () {
      expect(const BatteryStatus(level: 50, charging: true).powered, isTrue);
    });

    test('완충(충전 종료)이어도 true — 케이블이 꽂혀 있는 상태', () {
      expect(
        const BatteryStatus(level: 100, full: true, plugged: true).powered,
        isTrue,
      );
    });

    test('케이블만 꽂힌 상태도 true', () {
      expect(const BatteryStatus(level: 50, plugged: true).powered, isTrue);
    });

    test('배터리 구동 중이면 false', () {
      expect(const BatteryStatus(level: 50).powered, isFalse);
    });
  });

  group('low', () {
    test('배터리 구동 + 임계값 이하 → true', () {
      expect(const BatteryStatus(level: 20).low, isTrue);
      expect(const BatteryStatus(level: 5).low, isTrue);
    });

    test('임계값 초과면 false', () {
      expect(const BatteryStatus(level: 21).low, isFalse);
    });

    test('잔량이 낮아도 충전 중이면 경고하지 않는다', () {
      expect(const BatteryStatus(level: 5, charging: true).low, isFalse);
    });

    test('잔량을 모르면 false', () {
      expect(const BatteryStatus().low, isFalse);
    });
  });

  test('값 동등성 — 같은 상태면 == (리빌드 판단에 쓰임)', () {
    expect(
      const BatteryStatus(level: 50, charging: true),
      const BatteryStatus(level: 50, charging: true),
    );
    expect(
      const BatteryStatus(level: 50, charging: true),
      isNot(const BatteryStatus(level: 50)),
    );
  });
}
