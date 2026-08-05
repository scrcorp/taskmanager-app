/// BatteryIndicator widget tests.
///
/// 앱 고정 상태에서 상태바가 없으므로 이 칩이 유일한 충전 확인 수단이다.
/// "충전 중인지 한눈에 보이는가" 를 UI 레벨에서 고정한다.

import 'package:attendance/models/battery_status.dart';
import 'package:attendance/providers/device_power_provider.dart';
import 'package:attendance/widgets/battery_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:htm_core/htm_core.dart';

import '_test_helpers.dart';

void main() {
  Future<void> pumpWith(WidgetTester tester, BatteryStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          batteryStatusProvider.overrideWith((ref) => Stream.value(status)),
        ],
        child: wrapForTest(const BatteryIndicator()),
      ),
    );
    await tester.pump();
  }

  /// 주어진 배경색을 가진 Container 가 있는지.
  bool hasBackground(WidgetTester tester, Color color) => tester
      .widgetList<Container>(find.byType(Container))
      .any((w) => (w.decoration as BoxDecoration?)?.color == color);

  testWidgets('배터리 구동 중 — 잔량 퍼센트를 표시한다', (tester) async {
    await pumpWith(tester, const BatteryStatus(level: 85));

    expect(find.text('85%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_6_bar_rounded), findsOneWidget);
  });

  testWidgets('충전 중 — 번개 아이콘 + 초록 배경으로 강조', (tester) async {
    await pumpWith(tester, const BatteryStatus(level: 62, charging: true));

    expect(find.text('62%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
    expect(hasBackground(tester, AppColors.successBg), isTrue);

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.battery_charging_full_rounded),
    );
    expect(icon.color, AppColors.success);
  });

  testWidgets('완충 — 충전 아이콘 대신 꽉 찬 아이콘, 강조 배경 없음', (tester) async {
    await pumpWith(
      tester,
      const BatteryStatus(level: 100, full: true, plugged: true),
    );

    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_full_rounded), findsOneWidget);
    expect(hasBackground(tester, AppColors.successBg), isFalse);
  });

  testWidgets('저전력 — 빨간 배경으로 경고', (tester) async {
    await pumpWith(tester, const BatteryStatus(level: 12));

    expect(find.text('12%'), findsOneWidget);
    expect(hasBackground(tester, AppColors.dangerBg), isTrue);

    final icon = tester.widget<Icon>(find.byIcon(Icons.battery_1_bar_rounded));
    expect(icon.color, AppColors.danger);
  });

  testWidgets('잔량 충분 — 조용한 회색, 배경 없음', (tester) async {
    await pumpWith(tester, const BatteryStatus(level: 80));

    expect(hasBackground(tester, AppColors.successBg), isFalse);
    expect(hasBackground(tester, AppColors.dangerBg), isFalse);

    final icon = tester.widget<Icon>(find.byIcon(Icons.battery_6_bar_rounded));
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('상태를 모르면 자리를 차지하지 않는다 — 안드로이드가 아닌 환경', (tester) async {
    await pumpWith(tester, BatteryStatus.unknown);

    expect(find.text('—'), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('툴팁에 상태 문구와 잔량이 함께 들어간다', (tester) async {
    await pumpWith(tester, const BatteryStatus(level: 45, charging: true));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Charging · 45%');
  });
}
