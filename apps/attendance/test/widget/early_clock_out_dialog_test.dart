/// EarlyClockOutDialog widget test — Phase 5 Stage E.

import 'package:attendance/models/early_clock_out_reason.dart';
import 'package:attendance/widgets/early_clock_out_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';


Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

EarlyClockOutDialog _build({
  void Function(EarlyClockOutReason, String?)? onSubmit,
  VoidCallback? onCancel,
  int remainingMinutes = 240,
  String scheduledEnd = '23:50',
}) =>
    EarlyClockOutDialog(
      userName: 'Marcus Lee',
      scheduledEnd: scheduledEnd,
      remainingMinutes: remainingMinutes,
      onSubmit: onSubmit ?? (_, __) {},
      onCancel: onCancel ?? () {},
    );

bool _isSubmitEnabled(WidgetTester tester) {
  final btn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit & Clock Out'),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('헤더 + 이름 + 5개 사유 라디오 모두 렌더, 초기 Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    expect(find.text('EARLY CLOCK OUT'), findsOneWidget);
    expect(find.text('Marcus Lee, why are you leaving early?'), findsOneWidget);
    for (final r in EarlyClockOutReason.values) {
      expect(find.text(r.label), findsOneWidget, reason: r.name);
    }
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('남은 시간 4h 0m → "4h 0m remaining" 표시', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build(remainingMinutes: 240)));
    expect(find.textContaining('4h 0m remaining'), findsOneWidget);
    expect(find.textContaining('23:50'), findsOneWidget);
  });

  testWidgets('Cancel 탭 → onCancel 호출', (tester) async {
    await _useTabletSurface(tester);
    var canceled = 0;
    await tester.pumpWidget(wrapForTest(_build(onCancel: () => canceled++)));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(canceled, 1);
  });

  testWidgets('non-other reason 선택 → Submit 활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    await tester.tap(find.text(EarlyClockOutReason.feelingUnwell.label));
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);
  });

  testWidgets('Other 선택 → textarea 노출, Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    await tester.tap(find.text(EarlyClockOutReason.other.label));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('Other + detail 입력 → Submit 활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    await tester.tap(find.text(EarlyClockOutReason.other.label));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Doctor appointment');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);
  });

  testWidgets('Other + detail 공백만 → Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    await tester.tap(find.text(EarlyClockOutReason.other.label));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('non-other reason 선택 + Submit → onSubmit(reason, null)', (tester) async {
    await _useTabletSurface(tester);
    EarlyClockOutReason? gotReason;
    String? gotDetail;
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r, d) {
        gotReason = r;
        gotDetail = d;
      })),
    );
    await tester.tap(find.text(EarlyClockOutReason.familyEmergency.label));
    await tester.pump();
    await tester.tap(find.text('Submit & Clock Out'));
    await tester.pump();
    expect(gotReason, EarlyClockOutReason.familyEmergency);
    expect(gotDetail, isNull);
  });

  testWidgets('Other + detail + Submit → onSubmit(other, trimmed detail)', (tester) async {
    await _useTabletSurface(tester);
    EarlyClockOutReason? gotReason;
    String? gotDetail;
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r, d) {
        gotReason = r;
        gotDetail = d;
      })),
    );
    await tester.tap(find.text(EarlyClockOutReason.other.label));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Need to pick up child  ');
    await tester.pump();
    await tester.tap(find.text('Submit & Clock Out'));
    await tester.pump();
    expect(gotReason, EarlyClockOutReason.other);
    expect(gotDetail, 'Need to pick up child');
  });
}
