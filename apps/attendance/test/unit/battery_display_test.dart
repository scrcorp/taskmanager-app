/// 배터리 아이콘/색/라벨 매핑 unit tests.
///
/// 임계값(빨강 20% 이하, 주황 35% 이하)을 여기서 고정한다 — 색이 조용히
/// 바뀌면 매장에서 저전력을 놓치게 된다.

import 'package:attendance/models/battery_status.dart';
import 'package:attendance/utils/battery_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:htm_core/htm_core.dart';

void main() {
  group('batteryIconFor', () {
    test('충전 중이면 잔량과 무관하게 번개 아이콘', () {
      expect(
        batteryIconFor(const BatteryStatus(level: 10, charging: true)),
        Icons.battery_charging_full_rounded,
      );
    });

    test('완충이면 꽉 찬 아이콘', () {
      expect(
        batteryIconFor(const BatteryStatus(level: 100, full: true)),
        Icons.battery_full_rounded,
      );
    });

    test('케이블만 꽂힌 상태도 충전 아이콘 — 사용자에겐 "전원 연결됨"', () {
      expect(
        batteryIconFor(const BatteryStatus(level: 60, plugged: true)),
        Icons.battery_charging_full_rounded,
      );
    });

    test('잔량을 모르면 unknown 아이콘', () {
      expect(batteryIconFor(const BatteryStatus()), Icons.battery_unknown_rounded);
    });

    test('배터리 구동 시 잔량 구간별 아이콘', () {
      expect(batteryIconFor(const BatteryStatus(level: 100)),
          Icons.battery_full_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 85)),
          Icons.battery_6_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 70)),
          Icons.battery_5_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 55)),
          Icons.battery_4_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 40)),
          Icons.battery_3_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 25)),
          Icons.battery_2_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 15)),
          Icons.battery_1_bar_rounded);
      expect(batteryIconFor(const BatteryStatus(level: 5)),
          Icons.battery_alert_rounded);
    });
  });

  group('batteryColorFor', () {
    test('전원 연결 상태는 항상 초록 — 잔량이 낮아도 걱정할 일이 아님', () {
      expect(batteryColorFor(const BatteryStatus(level: 5, charging: true)),
          AppColors.success);
      expect(batteryColorFor(const BatteryStatus(level: 100, full: true)),
          AppColors.success);
      expect(batteryColorFor(const BatteryStatus(level: 40, plugged: true)),
          AppColors.success);
    });

    test('저전력 임계값(20%) 이하는 빨강', () {
      expect(batteryColorFor(const BatteryStatus(level: 20)), AppColors.danger);
      expect(batteryColorFor(const BatteryStatus(level: 3)), AppColors.danger);
    });

    test('경고 임계값(35%) 이하는 주황', () {
      expect(batteryColorFor(const BatteryStatus(level: 21)), AppColors.warning);
      expect(batteryColorFor(const BatteryStatus(level: 35)), AppColors.warning);
    });

    test('여유 있으면 조용한 회색', () {
      expect(batteryColorFor(const BatteryStatus(level: 36)),
          AppColors.textSecondary);
      expect(batteryColorFor(const BatteryStatus(level: 90)),
          AppColors.textSecondary);
    });

    test('잔량을 모르면 흐린 회색', () {
      expect(batteryColorFor(const BatteryStatus()), AppColors.textMuted);
    });
  });

  group('batteryLabelFor', () {
    test('잔량 퍼센트 표기', () {
      expect(batteryLabelFor(const BatteryStatus(level: 85)), '85%');
      expect(batteryLabelFor(const BatteryStatus(level: 0)), '0%');
    });

    test('모르면 대시 — 0% 로 지어내지 않는다', () {
      expect(batteryLabelFor(const BatteryStatus()), '—');
    });
  });

  group('batteryNeedsAttention', () {
    test('충전 중이면 강조', () {
      expect(batteryNeedsAttention(const BatteryStatus(level: 50, charging: true)),
          isTrue);
    });

    test('저전력이면 강조', () {
      expect(batteryNeedsAttention(const BatteryStatus(level: 10)), isTrue);
    });

    test('평상시(배터리 구동, 잔량 충분)엔 강조하지 않는다', () {
      expect(batteryNeedsAttention(const BatteryStatus(level: 80)), isFalse);
    });

    test('완충 상태는 강조하지 않는다 — 알릴 일이 없음', () {
      expect(
        batteryNeedsAttention(
          const BatteryStatus(level: 100, full: true, plugged: true),
        ),
        isFalse,
      );
    });
  });
}
