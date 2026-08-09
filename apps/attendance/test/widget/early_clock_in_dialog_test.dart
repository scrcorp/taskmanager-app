/// EarlyClockInDialog widget test.
///
/// 핵심은 "매니저 없이도 사유를 넣어 실제로 출근을 찍을 수 있는가" — 이 화면이
/// 없으면 일찍 와달라고 불린 직원이 출근 기록을 못 남긴다(원래 문제).
///
/// 얼마나 이른지 표시도 함께 본다. 서버가 시간 상한을 두지 않으므로 오조작
/// (다음날 shift 선택 등)을 사용자가 알아채는 장치가 이 문구뿐이다.

import 'package:attendance/widgets/early_clock_in_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

EarlyClockInDialog _build({
  ValueChanged<String>? onSubmit,
  VoidCallback? onCancel,
  int minutesEarly = 125,
  String? errorText,
}) =>
    EarlyClockInDialog(
      userName: 'Marcus Lee',
      minutesEarly: minutesEarly,
      onSubmit: onSubmit ?? (_) {},
      onCancel: onCancel ?? () {},
      errorText: errorText,
    );

bool _isSubmitEnabled(WidgetTester tester) {
  final btn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit & Clock In'),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('헤더 + 이른 정도 + 프리셋 렌더, 초기 Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));

    expect(find.text('EARLY CLOCK-IN'), findsOneWidget);
    expect(find.text('2h 5m before your shift starts'), findsOneWidget);
    expect(find.text('Asked to come in early'), findsOneWidget);
    expect(find.text('Covering for someone'), findsOneWidget);
    expect(find.text('Store needs help now'), findsOneWidget);
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('프리셋 선택 → Submit 활성 + 라벨 문자열 전달', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r) => submitted = r)),
    );

    await tester.tap(find.text('Asked to come in early'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Asked to come in early');
  });

  testWidgets('Other 선택 → 입력 전 Submit 비활성, 입력 후 활성 + 그 문장 전달',
      (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r) => submitted = r)),
    );

    await tester.tap(find.text('Other (please specify)'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);

    await tester.enterText(find.byType(TextField), 'Bus arrived early');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Bus arrived early');
  });

  testWidgets('취소 → onCancel 호출 (출근은 성립하지 않는다)', (tester) async {
    await _useTabletSurface(tester);
    var cancelled = false;
    await tester.pumpWidget(
      wrapForTest(_build(onCancel: () => cancelled = true)),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    expect(cancelled, true);
  });

  testWidgets('서버 거부 메시지는 화면 안에서 보여준다 (raw 에러 대신)', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(
      wrapForTest(_build(errorText: 'Selected shift is not available')),
    );

    expect(find.text('Selected shift is not available'), findsOneWidget);
  });

  testWidgets('60분 미만이면 분만 표시', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build(minutesEarly: 45)));

    expect(find.text('45m before your shift starts'), findsOneWidget);
  });
}
