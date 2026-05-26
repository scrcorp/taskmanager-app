/// SuccessModal widget test — Phase 5 Stage G.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/widgets/success_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';


SuccessModal _build({
  AttendanceAction action = AttendanceAction.clockIn,
  VoidCallback? onClose,
  bool autoClose = true,
  Duration autoCloseAfter = const Duration(seconds: 5),
  String userName = 'Marcus',
}) =>
    SuccessModal(
      userName: userName,
      action: action,
      onClose: onClose ?? () {},
      autoClose: autoClose,
      autoCloseAfter: autoCloseAfter,
    );

void main() {
  testWidgets('clock_in → 타이틀 + 이름 보간 + OK', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(action: AttendanceAction.clockIn)));
    expect(find.text('CLOCKED IN'), findsOneWidget);
    expect(find.text('Have a great shift, Marcus!'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('clock_out → "Great work today"', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(action: AttendanceAction.clockOut)));
    expect(find.text('CLOCKED OUT'), findsOneWidget);
    expect(find.text('Great work today, Marcus!'), findsOneWidget);
  });

  testWidgets('break_short_paid → "See you in 10"', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(action: AttendanceAction.breakShortPaid)));
    expect(find.text('ON 10-MIN BREAK'), findsOneWidget);
    expect(find.text('See you in 10, Marcus!'), findsOneWidget);
  });

  testWidgets('break_long_unpaid → "Enjoy your meal"', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(action: AttendanceAction.breakLongUnpaid)));
    expect(find.text('MEAL BREAK'), findsOneWidget);
    expect(find.text('Enjoy your meal, Marcus!'), findsOneWidget);
  });

  testWidgets('break_end → "Welcome back"', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(action: AttendanceAction.breakEnd)));
    expect(find.text('BACK TO WORK'), findsOneWidget);
    expect(find.text('Welcome back, Marcus!'), findsOneWidget);
  });

  testWidgets('OK 탭 → onClose 호출', (tester) async {
    var closed = 0;
    await tester.pumpWidget(wrapForTest(_build(onClose: () => closed++)));
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('autoClose=true → 안내 텍스트 노출', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(autoCloseAfter: const Duration(seconds: 5))));
    expect(find.text('Closes automatically in 5 seconds'), findsOneWidget);
  });

  testWidgets('autoClose=false → 안내 텍스트 미노출 + 시간 지나도 onClose 안 불림', (tester) async {
    var closed = 0;
    await tester.pumpWidget(wrapForTest(_build(
      autoClose: false,
      onClose: () => closed++,
    )));
    expect(find.text('Closes automatically in 5 seconds'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(closed, 0);
  });

  testWidgets('autoClose=true → autoCloseAfter 경과 시 onClose 자동 호출', (tester) async {
    var closed = 0;
    await tester.pumpWidget(wrapForTest(_build(
      autoClose: true,
      autoCloseAfter: const Duration(seconds: 5),
      onClose: () => closed++,
    )));
    await tester.pump(const Duration(seconds: 4));
    expect(closed, 0);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(closed, 1);
  });

  testWidgets('userName 보간 — 다른 이름', (tester) async {
    await tester.pumpWidget(wrapForTest(_build(
      action: AttendanceAction.clockOut,
      userName: 'Sarah Kim',
    )));
    expect(find.text('Great work today, Sarah Kim!'), findsOneWidget);
  });

  testWidgets('dispose 시 timer 취소 — onClose 추가 호출 없음', (tester) async {
    var closed = 0;
    await tester.pumpWidget(wrapForTest(_build(
      autoCloseAfter: const Duration(seconds: 5),
      onClose: () => closed++,
    )));
    await tester.pumpWidget(wrapForTest(const SizedBox()));
    await tester.pump(const Duration(seconds: 6));
    expect(closed, 0);
  });
}
