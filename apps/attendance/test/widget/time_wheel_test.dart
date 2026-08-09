/// Widget tests — TimeWheel 분 컬럼이 5분 단위만 노출하는지.
///
/// 서버 키오스크 step 과 어긋나면 "고를 수는 있는데 저장은 안 되는" 값이 생기므로,
/// 화면에 1분 단위 눈금이 다시 등장하는 회귀를 여기서 막는다.

import 'package:attendance/utils/schedule_edit_logic.dart';
import 'package:attendance/widgets/time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 분 컬럼(오른쪽 휠) 안에서만 라벨을 찾는다 — 시 컬럼의 같은 숫자와 헷갈리지 않게.
Finder _inMinuteColumn(String label) => find.descendant(
      of: find.byType(ListWheelScrollView).last,
      matching: find.text(label),
    );

Future<void> _pump(WidgetTester tester, {required int initialMinutes, required void Function(int) onChanged}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TimeWheel(initialMinutes: initialMinutes, onChanged: onChanged),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('분 컬럼에 5분 배수가 아닌 눈금이 없다', (tester) async {
    await _pump(tester, initialMinutes: 9 * 60, onChanged: (_) {});

    // 5분 배수는 렌더된다 (초기 위치 근처).
    expect(_inMinuteColumn('00'), findsOneWidget);
    expect(_inMinuteColumn('05'), findsOneWidget);

    // 1분 단위 눈금은 없어야 한다.
    for (final label in ['01', '02', '03', '04', '17', '59']) {
      expect(_inMinuteColumn(label), findsNothing, reason: '분 컬럼에 $label 이 노출됨');
    }
  });

  testWidgets('step 을 벗어난 초기값은 그 값 그대로 보여준다 (워크인 보존)', (tester) async {
    // 09:07 (워크인의 실제 clock-in 시각) → 09:07 로 표시돼야 한다.
    // 임의로 09:05 로 보여주면 매니저가 안 건드린 값이 바뀐 것처럼 보인다.
    await _pump(tester, initialMinutes: 9 * 60 + 7, onChanged: (_) {});
    expect(_inMinuteColumn('07'), findsOneWidget);
    // 예외 눈금은 그 값 하나뿐 — 다른 1분 단위가 같이 열리면 안 된다.
    for (final label in ['06', '08', '09']) {
      expect(_inMinuteColumn(label), findsNothing, reason: '분 컬럼에 $label 이 노출됨');
    }
  });

  testWidgets('step 을 벗어난 초기값도 다른 눈금을 고르면 5분 단위가 된다', (tester) async {
    final emitted = <int>[];
    await _pump(tester, initialMinutes: 9 * 60 + 7, onChanged: emitted.add);

    await tester.drag(find.byType(ListWheelScrollView).last, const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(emitted, isNotEmpty);
    for (final v in emitted) {
      expect(v % scheduleStepMinutes, 0, reason: 'emit=$v');
    }
  });

  testWidgets('휠을 굴리면 5분 배수 값만 emit 된다', (tester) async {
    final emitted = <int>[];
    await _pump(tester, initialMinutes: 9 * 60, onChanged: emitted.add);

    // 분 컬럼(오른쪽)을 위로 드래그 → 다음 항목들 선택
    final wheels = find.byType(ListWheelScrollView);
    await tester.drag(wheels.last, const Offset(0, -140));
    await tester.pumpAndSettle();

    expect(emitted, isNotEmpty);
    for (final v in emitted) {
      expect(v % scheduleStepMinutes, 0, reason: 'emit=$v');
    }
  });
}
