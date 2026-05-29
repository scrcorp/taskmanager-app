/// Widget/unit tests — StoreClock (Issue 10 Step 6).

import 'package:attendance/widgets/store_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('labelFromIana — 도시 라벨', () {
    expect(StoreClock.labelFromIana('America/Los_Angeles'), 'Los Angeles');
    expect(StoreClock.labelFromIana('Asia/Seoul'), 'Seoul');
    expect(StoreClock.labelFromIana(null), isNull);
    expect(StoreClock.labelFromIana(''), isNull);
  });

  testWidgets('매장 시각 + tz 라벨 표시 (offset 적용)', (tester) async {
    // UTC 04:17:23 + (-420분) = 21:17:23 (store wall-clock)
    final now = DateTime.utc(2026, 5, 29, 4, 17, 23);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StoreClock(now: now, offsetMinutes: -420, tzLabel: 'Los Angeles')),
    ));
    expect(find.text('21:17:23'), findsOneWidget);
    expect(find.text('Los Angeles'), findsOneWidget);
  });

  testWidgets('offset null 이면 그대로 (라벨 없으면 미표시)', (tester) async {
    final now = DateTime.utc(2026, 5, 29, 9, 5, 0);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StoreClock(now: now, offsetMinutes: null)),
    ));
    expect(find.text('09:05:00'), findsOneWidget);
  });

  testWidgets('showSeconds=false → HH:mm', (tester) async {
    final now = DateTime.utc(2026, 5, 29, 9, 5, 30);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StoreClock(now: now, offsetMinutes: null, showSeconds: false)),
    ));
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('use24Hour=false → 12시간제 (a/p)', (tester) async {
    final now = DateTime.utc(2026, 5, 29, 21, 5, 0); // 21:05 → 9:05 PM
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StoreClock(now: now, offsetMinutes: null, use24Hour: false, showSeconds: false)),
    ));
    expect(find.textContaining('9:05'), findsOneWidget);
  });
}
