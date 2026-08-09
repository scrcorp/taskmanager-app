/// BreakReasonDialog widget test.
///
/// 핵심은 "사유를 넣어 실제로 끝낼 수 있는가" — 이 화면이 없어서 스태프가
/// 35분 넘은 meal break 를 못 끝내던 게 원래 버그다.

import 'package:attendance/widgets/break_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

BreakReasonDialog _build({
  ValueChanged<String>? onSubmit,
  VoidCallback? onCancel,
  int elapsedMinutes = 42,
  String? errorText,
}) =>
    BreakReasonDialog(
      userName: 'Marcus Lee',
      elapsedMinutes: elapsedMinutes,
      onSubmit: onSubmit ?? (_) {},
      onCancel: onCancel ?? () {},
      errorText: errorText,
    );

bool _isSubmitEnabled(WidgetTester tester) {
  final btn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit & End Break'),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('헤더 + 경과시간 + 프리셋 렌더, 초기 Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));

    expect(find.text('BREAK OVER ALLOWANCE'), findsOneWidget);
    expect(find.text('42 minutes on break so far'), findsOneWidget);
    expect(find.text('Forgot to end break'), findsOneWidget);
    expect(find.text('Manager approved longer break'), findsOneWidget);
    expect(find.text('Personal emergency'), findsOneWidget);
    expect(find.text('Waiting for coverage'), findsOneWidget);
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('프리셋 선택 → Submit 활성, 라벨이 그대로 전달된다', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    await tester.pumpWidget(wrapForTest(_build(onSubmit: (r) => submitted = r)));

    await tester.tap(find.text('Waiting for coverage'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & End Break'));
    await tester.pump();
    expect(submitted, 'Waiting for coverage');
  });

  testWidgets('Other 선택 → 입력 전엔 Submit 비활성, 입력하면 그 텍스트가 전달', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    await tester.pumpWidget(wrapForTest(_build(onSubmit: (r) => submitted = r)));

    await tester.tap(find.text('Other (please specify)'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);

    await tester.enterText(find.byType(TextField), 'Bus broke down');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & End Break'));
    await tester.pump();
    expect(submitted, 'Bus broke down');
  });

  testWidgets('Cancel → onCancel 호출', (tester) async {
    await _useTabletSurface(tester);
    var cancelled = false;
    await tester.pumpWidget(wrapForTest(_build(onCancel: () => cancelled = true)));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    expect(cancelled, true);
  });

  testWidgets('errorText 가 있으면 화면 안에 표시된다 (raw 에러 토스트 대신)', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(
      wrapForTest(_build(errorText: 'Could not end break. Try again.')),
    );
    expect(find.text('Could not end break. Try again.'), findsOneWidget);
  });
}
