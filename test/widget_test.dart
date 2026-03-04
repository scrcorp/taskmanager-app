/// 기본 위젯 테스트 — Flutter 프로젝트 생성 시 자동 생성된 파일
///
/// 현재 MyApp 참조가 유효하지 않아 실행되지 않음 (앱 엔트리가 TaskManagerApp).
/// TODO: 실제 앱에 맞는 테스트로 교체 필요.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
