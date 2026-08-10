/// Widget tests — Edit Times 모달 (상태 전이 없이 시각만 보정).

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/screens/attendance/attendance_manage_edit_times_modal.dart';
import 'package:attendance/widgets/time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminScheduleRow _row({
  String state = 'working',
  String? clockIn = '09:07',
  String? clockOut,
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
    startHHmm: '09:00',
    endHHmm: '17:00',
    status: 'confirmed',
    attendanceId: 'a1',
    state: state,
    breaks: breaks,
    attendanceStatus: state,
    clockInDisplay: clockIn,
    clockOutDisplay: clockOut,
  );
}

Future<void> _pump(WidgetTester tester, AdminScheduleRow row) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: AttendanceManageEditTimesModal(row: row)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('clock-in 만 있으면 칩 1개 + 휠 1개', (tester) async {
    await _pump(tester, _row());
    expect(find.text('Edit Times'), findsOneWidget);
    expect(find.byType(TimeWheel), findsOneWidget);
    expect(find.text('Clock In'), findsOneWidget);
    expect(find.text('Clock Out'), findsNothing);
  });

  testWidgets('휠 분 컬럼이 1분 단위 — 5분 배수가 아닌 시각도 고를 수 있다', (tester) async {
    await _pump(tester, _row());
    final wheel = tester.widget<TimeWheel>(find.byType(TimeWheel));
    expect(wheel.stepMinutes, 1);
    // 09:07 이 그대로 초기값 (반올림되지 않는다)
    expect(wheel.initialMinutes, 9 * 60 + 7);
  });

  testWidgets('break 세션이 있으면 start/end 칩이 함께 뜬다', (tester) async {
    await _pump(
      tester,
      _row(
        clockOut: '17:00',
        breaks: const [
          ManageBreak(id: 'b1', type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ),
    );
    expect(find.text('Clock In'), findsOneWidget);
    expect(find.text('Clock Out'), findsOneWidget);
    expect(find.text('Meal start'), findsOneWidget);
    expect(find.text('Meal end'), findsOneWidget);
  });

  testWidgets('변경 전에는 Save 비활성 (사유만 골라도 안 된다)', (tester) async {
    await _pump(tester, _row());
    final save = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save Times'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Unchanged'), findsOneWidget);

    await tester.ensureVisible(find.text('Wrong time recorded'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong time recorded'));
    await tester.pumpAndSettle();
    final save2 = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save Times'),
    );
    expect(save2.onPressed, isNull, reason: '시각이 안 바뀌었으면 저장할 게 없다');
  });

  testWidgets('기록이 하나도 없으면 안내만 (빈 편집 화면을 열지 않는다)', (tester) async {
    await _pump(tester, _row(state: 'upcoming', clockIn: null));
    expect(find.byType(TimeWheel), findsNothing);
    expect(find.textContaining('no recorded time'), findsOneWidget);
  });

  testWidgets('사유는 Required 로 표시된다', (tester) async {
    await _pump(tester, _row());
    expect(find.text('Required'), findsOneWidget);
  });
}
