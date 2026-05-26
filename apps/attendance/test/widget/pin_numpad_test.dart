/// PinNumpad widget test — Phase 5 Stage B.

import 'package:attendance/widgets/pin_numpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';


Future<void> _tapDigit(WidgetTester tester, String d) async {
  await tester.ensureVisible(find.text(d));
  await tester.tap(find.text(d));
  await tester.pump();
}

void main() {
  testWidgets('초기 상태 — Verify Identity 비활성, Show PIN 비활성', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));

    final submit = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify Identity'));
    expect(submit.onPressed, isNull);

    final showPin = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Show PIN'));
    expect(showPin.onPressed, isNull);
  });

  testWidgets('숫자 키 탭 → input 누적', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    await _tapDigit(tester, '1');
    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3');
    // 마스킹 (●●●). reveal=false 가 기본.
    expect(find.text('•••'), findsOneWidget);
  });

  testWidgets('Show PIN 토글 시 실제 PIN 표시', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    await _tapDigit(tester, '1');
    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3');
    await _tapDigit(tester, '4');

    expect(find.text('••••'), findsOneWidget);
    await tester.ensureVisible(find.text('Show PIN'));
    await tester.tap(find.text('Show PIN'));
    await tester.pump();
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('Hide PIN'), findsOneWidget);
  });

  testWidgets('CLEAR 탭 → 전체 삭제', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    for (final d in ['1', '2', '3']) {
      await _tapDigit(tester, d);
    }
    expect(find.text('•••'), findsOneWidget);

    await tester.ensureVisible(find.text('CLEAR'));
    await tester.tap(find.text('CLEAR'));
    await tester.pump();
    // 빈 input
    expect(find.text('•••'), findsNothing);
  });

  testWidgets('DEL — 마지막 한 글자만 제거', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    await _tapDigit(tester, '1');
    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3');

    await tester.ensureVisible(find.byIcon(Icons.backspace_outlined));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    // 2글자 남음
    expect(find.text('••'), findsOneWidget);
  });

  testWidgets('minLength 미만 → Verify 비활성', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    await _tapDigit(tester, '1');
    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3'); // 3 < minLength=4
    final submit = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify Identity'));
    expect(submit.onPressed, isNull);
  });

  testWidgets('minLength 도달 → Verify 활성 + 탭 시 onSubmit 호출 + state 리셋', (tester) async {
    String? submitted;
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (p) => submitted = p)));
    for (final d in ['1', '2', '3', '4']) {
      await _tapDigit(tester, d);
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify Identity'));
    await tester.pump();
    expect(submitted, '1234');
    // state 리셋 → Show PIN 비활성 다시
    final showPin = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Show PIN'));
    expect(showPin.onPressed, isNull);
  });

  testWidgets('maxLength 도달 — 추가 입력 무시', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));
    for (final d in ['1', '2', '3', '4', '5', '6']) {
      await _tapDigit(tester, d);
    }
    expect(find.text('••••••'), findsOneWidget);
    // 7번째 입력 → 무시
    await _tapDigit(tester, '7');
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('•••••••'), findsNothing);
  });

  testWidgets('enabled=false 면 숫자 키 / Verify 모두 동작 안 함', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      wrapForTest(PinNumpad(onSubmit: (p) => submitted = p, enabled: false)),
    );
    // 숫자 키 탭 — state 변경 없음
    await _tapDigit(tester, '1');
    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3');
    await _tapDigit(tester, '4');
    expect(find.text('••••'), findsNothing);

    // Verify Identity 비활성
    final submit = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify Identity'));
    expect(submit.onPressed, isNull);
    expect(submitted, isNull);
  });
}
