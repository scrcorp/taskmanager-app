/// Widget tests — Action Picker / Action Modal (Issue 10 Step 4).

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/screens/attendance/attendance_manage_action_modal.dart';
import 'package:attendance/widgets/manage_action_picker.dart';
import 'package:attendance/widgets/time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminScheduleRow _row({
  String state = 'upcoming',
  List<String> anomalies = const [],
  String? clockIn,
  List<ManageBreak> breaks = const [],
}) {
  return AdminScheduleRow(
    scheduleId: 's1',
    userId: 'u1',
    userName: 'María Rosa',
    workRoleId: null,
    workRoleName: null,
    shiftName: null,
    positionName: null,
    startHHmm: '09:30',
    endHHmm: '17:00',
    status: 'confirmed',
    attendanceId: 'a1',
    state: state,
    anomalies: anomalies,
    breaks: breaks,
    attendanceStatus: state,
    clockInDisplay: clockIn,
    clockOutDisplay: null,
  );
}

void main() {
  group('adminActionsForState', () {
    test('state별 액션 매핑', () {
      expect(adminActionsForState('upcoming'), [AdminAction.clockIn]);
      expect(adminActionsForState('working'), [
        AdminAction.clockOut,
        AdminAction.break10min,
        AdminAction.breakMeal,
        AdminAction.editTimes,
        AdminAction.undoClockIn,
      ]);
      expect(adminActionsForState('breaking'), [
        AdminAction.endBreak,
        AdminAction.clockOut,
        AdminAction.editTimes,
        AdminAction.undoClockIn,
      ]);
      expect(adminActionsForState('done'),
          [AdminAction.editTimes, AdminAction.reopenShift]);
    });

    test('clock 기록이 있는 상태엔 Edit Times 가 항상 있다 (상태 되돌리기 없이 시각 수정)', () {
      for (final state in ['working', 'breaking', 'done']) {
        expect(adminActionsForState(state), contains(AdminAction.editTimes),
            reason: '$state 에 Edit Times 없음');
      }
      // upcoming 은 고칠 기록 자체가 없다
      expect(adminActionsForState('upcoming'), isNot(contains(AdminAction.editTimes)));
    });
  });

  group('ManageActionPicker', () {
    testWidgets('upcoming → Clock In 만', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageActionPicker(row: _row(state: 'upcoming'), now: DateTime(2026, 5, 29, 12, 0), onPick: (_) {}),
        ),
      ));
      expect(find.text('Clock In'), findsOneWidget);
      expect(find.text('Clock Out'), findsNothing);
    });

    testWidgets('working → Clock Out / Break / Undo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageActionPicker(row: _row(state: 'working', clockIn: '09:02'), now: DateTime(2026, 5, 29, 12, 0), onPick: (_) {}),
        ),
      ));
      expect(find.text('Clock Out'), findsOneWidget);
      expect(find.text('Start 10-min Break'), findsOneWidget);
      expect(find.text('Undo Clock-in'), findsOneWidget);
      expect(find.text('Edit Times'), findsOneWidget);
    });
  });

  group('AttendanceManageActionModal', () {
    testWidgets('Clock In → 휠 + REASON Optional', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AttendanceManageActionModal(action: AdminAction.clockIn, row: _row())),
        ),
      ));
      expect(find.byType(TimeWheel), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
    });

    testWidgets('Undo Clock-in → REASON Required (시각 없음)', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AttendanceManageActionModal(action: AdminAction.undoClockIn, row: _row(state: 'working', clockIn: '09:02'))),
        ),
      ));
      expect(find.byType(TimeWheel), findsNothing);
      expect(find.text('Required'), findsOneWidget);
    });
  });
}
