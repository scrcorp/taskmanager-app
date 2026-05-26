/// StaffBlock widget test — Phase 5 Stage A.

import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/widgets/staff_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

TodayStaffRow _row({
  String name = 'Marcus Lee',
  String status = 'working',
  String? clockInDisplay,
}) =>
    TodayStaffRow(
      userId: 'u1',
      userName: name,
      scheduleId: null,
      scheduledStart: null,
      scheduledEnd: null,
      scheduledStartDisplay: null,
      scheduledEndDisplay: null,
      clockIn: null,
      clockOut: null,
      clockInDisplay: clockInDisplay,
      clockOutDisplay: null,
      status: status,
      currentBreak: null,
      paidBreakMinutes: 0,
      unpaidBreakMinutes: 0,
    );


void main() {
  testWidgets('이름 + 이니셜 (ML) 렌더', (tester) async {
    await tester.pumpWidget(
      wrapForTest(StaffBlock(
        row: _row(name: 'Marcus Lee'),
        selected: false,
        onTap: () {},
      )),
    );
    expect(find.text('Marcus Lee'), findsOneWidget);
    expect(find.text('ML'), findsOneWidget);
  });

  testWidgets('working + clockInDisplay → "In 09:02" 서브 표시', (tester) async {
    await tester.pumpWidget(
      wrapForTest(StaffBlock(
        row: _row(status: 'working', clockInDisplay: '09:02'),
        selected: false,
        onTap: () {},
      )),
    );
    expect(find.text('In 09:02'), findsOneWidget);
  });

  testWidgets('탭 시 onTap 호출', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrapForTest(StaffBlock(row: _row(), selected: false, onTap: () => tapped++)),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('selected=true 면 accent border 적용 (Container BoxDecoration)', (tester) async {
    await tester.pumpWidget(
      wrapForTest(StaffBlock(row: _row(), selected: true, onTap: () {})),
    );
    // 첫 Container 의 border 가 transparent 가 아닌 색이어야 함.
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(StaffBlock), matching: find.byType(Container)).first,
    );
    final deco = container.decoration as BoxDecoration;
    expect(deco.border, isNotNull);
    // border side color 가 transparent 아님
    final side = (deco.border as Border).top;
    expect(side.color.a, greaterThan(0));
  });
}
