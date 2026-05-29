/// Widget tests — 공용 ScheduleStaffCard / ScheduleStaffDetailPanel (Issue 10 통합).

import 'package:attendance/models/schedule_staff_view.dart';
import 'package:attendance/providers/attendance_manage_provider.dart' show ManageBreak;
import 'package:attendance/widgets/schedule_staff_card.dart';
import 'package:attendance/widgets/schedule_staff_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduleStaffView _view({
  String name = 'Sofia Mendes',
  String? roleLabel,
  String state = 'working',
  List<String> anomalies = const [],
  List<ManageBreak> breaks = const [],
  String? clockIn,
  String? clockOut,
}) {
  return ScheduleStaffView(
    id: 's1',
    name: name,
    roleLabel: roleLabel,
    state: state,
    anomalies: anomalies,
    breaks: breaks,
    scheduledStart: '10:00',
    scheduledEnd: '18:00',
    clockIn: clockIn,
    clockOut: clockOut,
  );
}

Future<void> _pump(WidgetTester t, Widget child) =>
    t.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  final now = DateTime(2026, 5, 29, 12, 0);

  group('ScheduleStaffCard', () {
    testWidgets('working+late: 이름 + Late, Working 배지 없음', (tester) async {
      await _pump(tester, SizedBox(width: 280, child: ScheduleStaffCard(
        view: _view(state: 'working', anomalies: ['late'], clockIn: '10:24'),
        selected: false, now: now, onTap: () {})));
      expect(find.text('Sofia Mendes'), findsOneWidget);
      expect(find.text('Late'), findsOneWidget);
      expect(find.text('Working'), findsNothing);
    });

    testWidgets('breaking: Breaking 배지', (tester) async {
      await _pump(tester, SizedBox(width: 280, child: ScheduleStaffCard(
        view: _view(state: 'breaking', clockIn: '08:01', breaks: const [ManageBreak(type: 'paid_10min', start: '11:50', end: null)]),
        selected: false, now: now, onTap: () {})));
      expect(find.text('Breaking'), findsOneWidget);
    });
  });

  group('ScheduleStaffDetailPanel', () {
    testWidgets('null view → placeholder', (tester) async {
      await _pump(tester, SizedBox(width: 360, height: 600, child: ScheduleStaffDetailPanel(view: null, now: now)));
      expect(find.text('Pick a staff to see details'), findsOneWidget);
    });

    testWidgets('읽기 전용(staff): 액션 버튼 없음', (tester) async {
      await _pump(tester, SizedBox(width: 360, height: 700, child: ScheduleStaffDetailPanel(
        view: _view(name: 'Priya', state: 'breaking', clockIn: '08:01',
            breaks: const [ManageBreak(type: 'unpaid_meal', start: '12:30', end: '13:02')]),
        now: now)));
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('BREAKS'), findsOneWidget);
      expect(find.text('Actions'), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('manage(액션 콜백): Actions/Edit/Delete 표시', (tester) async {
      await _pump(tester, SizedBox(width: 360, height: 760, child: ScheduleStaffDetailPanel(
        view: _view(name: 'Marcus', state: 'working', clockIn: '09:02'),
        now: now, onActions: () {}, onEdit: () {}, onDelete: () {})));
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
