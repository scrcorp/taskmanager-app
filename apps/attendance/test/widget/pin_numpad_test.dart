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

  // Issue 5 fix: onTapDown 즉시 반응 — 같은 frame 안 연속 tap 도 모두 반영.
  testWidgets('빠른 연속 tap — pump 없이 6 키 연속 → 모두 누적 (5자리 마스킹)', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));

    // pump 호출 없이 연속 tap — frame 단위 처리 검증.
    // (InkResponse.onTapDown 은 down event 즉시 콜백, gesture arena 대기 없음)
    for (final d in const ['1', '2', '3', '4', '5']) {
      await tester.tap(find.text(d));
    }
    await tester.pump();
    // 5자리 마스킹 — 모두 반영됐다는 증거 (누락 시 dot 갯수 적음)
    expect(find.text('•••••'), findsOneWidget);
  });

  testWidgets('빠른 같은 키 연속 — 6 키 max 까지 누적', (tester) async {
    await tester.pumpWidget(wrapForTest(PinNumpad(onSubmit: (_) {})));

    // 같은 key '5' 를 6번 연속 — max 도달
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('5'));
    }
    await tester.pump();
    expect(find.text('••••••'), findsOneWidget);
  });
}
