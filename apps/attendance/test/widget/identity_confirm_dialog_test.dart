/// IdentityConfirmDialog widget test — Phase 5 Stage C.

import 'package:attendance/models/identify_response.dart';
import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/widgets/identity_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';


IdentifyResponse _user({
  String name = 'Marcus Lee',
  String? status = 'working',
  TodayStaffBreak? currentBreak,
}) =>
    IdentifyResponse(
      userId: 'u1',
      userName: name,
      todayStatus: status,
      currentBreak: currentBreak,
    );

void main() {
  testWidgets('이름 + 이니셜 + IS THIS YOU 헤더 렌더', (tester) async {
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(name: 'Marcus Lee'),
      onYes: () {},
      onClose: () {},
    )));
    expect(find.text('Marcus Lee'), findsOneWidget);
    expect(find.text('ML'), findsOneWidget);
    expect(find.text('IS THIS YOU?'), findsOneWidget);
  });

  testWidgets("working → status badge + Yes/Close 둘 다", (tester) async {
    var yesCount = 0;
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: 'working'),
      onYes: () => yesCount++,
      onClose: () {},
    )));
    expect(find.text('Currently working'), findsOneWidget);
    expect(find.text("Yes, it's me"), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text("Yes, it's me"));
    await tester.pump();
    expect(yesCount, 1);
  });

  testWidgets('no shift (todayStatus null) → orange box + Close 만', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: null),
      onYes: () {},
      onClose: () => closeCount++,
    )));
    expect(find.text('NO SHIFT TODAY'), findsOneWidget);
    expect(find.text("Yes, it's me"), findsNothing); // Yes 버튼 없음
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(closeCount, 1);
  });

  testWidgets('clocked_out → Close 만', (tester) async {
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: 'clocked_out'),
      onYes: () {},
      onClose: () {},
    )));
    expect(find.text('Shift completed'), findsOneWidget);
    expect(find.text("Yes, it's me"), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('on_break + currentBreak → break info 박스 (라벨 + Nm elapsed + hint)', (tester) async {
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 18)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: 'on_break', currentBreak: br),
      onYes: () {},
      onClose: () {},
      now: now,
    )));
    expect(find.textContaining('MEAL BREAK (UNPAID)'), findsOneWidget);
    expect(find.text('18m elapsed'), findsOneWidget);
    expect(find.textContaining('30m minimum'), findsOneWidget);
    // on_break 라도 Close 만 아님 (Yes/Close 둘 다)
    expect(find.text("Yes, it's me"), findsOneWidget);
  });

  testWidgets('upcoming → "Shift upcoming" 라벨', (tester) async {
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: 'upcoming'),
      onYes: () {},
      onClose: () {},
    )));
    expect(find.text('Shift upcoming'), findsOneWidget);
  });

  testWidgets('late → "Running late"', (tester) async {
    await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
      user: _user(status: 'late'),
      onYes: () {},
      onClose: () {},
    )));
    expect(find.text('Running late'), findsOneWidget);
  });
}
