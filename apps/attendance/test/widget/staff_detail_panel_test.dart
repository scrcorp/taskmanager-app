/// StaffDetailPanel widget test — Phase 5 Stage A.

import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/widgets/staff_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

TodayStaffRow _row({
  String name = 'Marcus Lee',
  String status = 'working',
  String? scheduledStartDisplay,
  String? scheduledEndDisplay,
  String? clockInDisplay,
  String? clockOutDisplay,
  TodayStaffBreak? currentBreak,
}) =>
    TodayStaffRow(
      userId: 'u1',
      userName: name,
      scheduleId: null,
      scheduledStart: null,
      scheduledEnd: null,
      scheduledStartDisplay: scheduledStartDisplay,
      scheduledEndDisplay: scheduledEndDisplay,
      clockIn: null,
      clockOut: null,
      clockInDisplay: clockInDisplay,
      clockOutDisplay: clockOutDisplay,
      status: status,
      currentBreak: currentBreak,
      paidBreakMinutes: 0,
      unpaidBreakMinutes: 0,
    );


void main() {
  testWidgets('row null → placeholder 표시', (tester) async {
    await tester.pumpWidget(wrapForTest(const StaffDetailPanel(row: null)));
    expect(find.text('Pick a staff to see details'), findsOneWidget);
  });

  testWidgets('row 있을 때 — 이름 / status 라벨 / scheduled range / clock 시간 표시', (tester) async {
    await tester.pumpWidget(
      wrapForTest(StaffDetailPanel(
        row: _row(
          name: 'Marcus Lee',
          status: 'working',
          scheduledStartDisplay: '09:00',
          scheduledEndDisplay: '17:00',
          clockInDisplay: '09:02',
        ),
      )),
    );
    expect(find.text('Marcus Lee'), findsOneWidget);
    expect(find.text('WORKING'), findsOneWidget);
    expect(find.text('09:00 – 17:00'), findsOneWidget);
    expect(find.text('09:02'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // Clock Out missing
  });

  testWidgets('on_break + currentBreak → break info 박스 + 경과 시간', (tester) async {
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 18)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(
      wrapForTest(StaffDetailPanel(row: _row(status: 'on_break', currentBreak: br), now: now)),
    );
    // 18m elapsed 표시
    expect(find.textContaining('18m elapsed'), findsOneWidget);
    // 라벨 (대문자)
    expect(find.text('MEAL BREAK (UNPAID)'), findsOneWidget);
    // hint 에 30분 이상 메시지 (under 30m too short)
    expect(find.textContaining('30m minimum'), findsOneWidget);
  });

  testWidgets('over 35m → warning hint "reason required"', (tester) async {
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 38)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(
      wrapForTest(StaffDetailPanel(row: _row(status: 'on_break', currentBreak: br), now: now)),
    );
    expect(find.textContaining('reason required'), findsOneWidget);
  });
}
