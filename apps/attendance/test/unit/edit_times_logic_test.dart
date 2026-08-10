/// Unit tests — edit_times_logic (Edit Times: 어떤 시각을 고칠 수 있고 무엇이 바뀌었나).

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/utils/edit_times_logic.dart';
import 'package:flutter_test/flutter_test.dart';

AdminScheduleRow _row({
  String? clockIn,
  String? clockOut,
  List<ManageBreak> breaks = const [],
  String state = 'working',
}) {
  return AdminScheduleRow(
    scheduleId: 's1',
    userId: 'u1',
    userName: 'Jane Doe',
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
    attendanceStatus: null,
    clockInDisplay: clockIn,
    clockOutDisplay: clockOut,
  );
}

void main() {
  group('buildTimeTargets', () {
    test('기록된 시각만 편집 칸이 된다', () {
      final targets = buildTimeTargets(_row(clockIn: '09:07'));
      expect(targets.map((t) => t.kind), [TimeTargetKind.clockIn]);
      expect(targets.first.originalMinutes, 9 * 60 + 7);
    });

    test('clock-in 이 없으면 편집 칸이 없다 (상태 전이는 이 화면 소관 아님)', () {
      expect(buildTimeTargets(_row()), isEmpty);
    });

    test('완료된 shift 는 in/out 두 칸', () {
      final targets = buildTimeTargets(_row(clockIn: '09:00', clockOut: '17:30'));
      expect(targets.map((t) => t.kind),
          [TimeTargetKind.clockIn, TimeTargetKind.clockOut]);
      expect(targets.last.originalMinutes, 17 * 60 + 30);
    });

    test('break 는 start/end 각각 칸이 되고 라벨에 종류가 붙는다', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [
          ManageBreak(id: 'b1', type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ));
      expect(targets.length, 3);
      expect(targets[1].label, 'Meal start');
      expect(targets[2].label, 'Meal end');
      expect(targets[1].breakId, 'b1');
    });

    test('진행 중 break 는 start 만 (종료 시각이 아직 없다)', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [ManageBreak(id: 'b1', type: 'paid_10min', start: '12:00')],
      ));
      expect(targets.length, 2);
      expect(targets[1].label, '10-min start');
    });

    test('break_id 없는 구버전 응답은 편집 대상에서 빠진다', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [
          ManageBreak(type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ));
      expect(targets.map((t) => t.kind), [TimeTargetKind.clockIn]);
    });

    test('target key 는 break 세션마다 다르다', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [
          ManageBreak(id: 'b1', type: 'paid_10min', start: '10:00', end: '10:10'),
          ManageBreak(id: 'b2', type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ));
      expect(targets.map((t) => t.key).toSet().length, targets.length);
    });
  });

  group('buildEditTimesPayload', () {
    test('바뀐 칸만 담는다', () {
      final targets = buildTimeTargets(_row(clockIn: '09:00', clockOut: '17:00'));
      final values = {for (final t in targets) t.key: t.originalMinutes};
      values[targets.first.key] = 9 * 60 + 3; // clock-in 만 3분 뒤로

      final payload = buildEditTimesPayload(targets, values);
      expect(payload.clockInHHmm, '09:03');
      expect(payload.clockOutHHmm, isNull);
      expect(payload.breaks, isEmpty);
      expect(payload.isEmpty, isFalse);
    });

    test('변경이 없으면 빈 payload', () {
      final targets = buildTimeTargets(_row(clockIn: '09:00'));
      final values = {for (final t in targets) t.key: t.originalMinutes};
      expect(buildEditTimesPayload(targets, values).isEmpty, isTrue);
    });

    test('한 break 의 start/end 가 같이 바뀌면 한 항목으로 합쳐진다', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [
          ManageBreak(id: 'b1', type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ));
      final values = {for (final t in targets) t.key: t.originalMinutes};
      values[targets[1].key] = 12 * 60 + 7;
      values[targets[2].key] = 12 * 60 + 44;

      final payload = buildEditTimesPayload(targets, values);
      expect(payload.breaks, [
        {'break_id': 'b1', 'start_hhmm': '12:07', 'end_hhmm': '12:44'},
      ]);
    });

    test('서로 다른 break 는 항목이 나뉜다', () {
      final targets = buildTimeTargets(_row(
        clockIn: '09:00',
        breaks: const [
          ManageBreak(id: 'b1', type: 'paid_10min', start: '10:00', end: '10:10'),
          ManageBreak(id: 'b2', type: 'unpaid_meal', start: '12:00', end: '12:30'),
        ],
      ));
      final values = {for (final t in targets) t.key: t.originalMinutes};
      values[targets[1].key] = 10 * 60 + 2; // b1 start
      values[targets[4].key] = 12 * 60 + 35; // b2 end

      final payload = buildEditTimesPayload(targets, values);
      expect(payload.breaks.length, 2);
      expect(payload.breaks.firstWhere((b) => b['break_id'] == 'b1'),
          {'break_id': 'b1', 'start_hhmm': '10:02'});
      expect(payload.breaks.firstWhere((b) => b['break_id'] == 'b2'),
          {'break_id': 'b2', 'end_hhmm': '12:35'});
    });

    test('1분 단위 값도 그대로 실린다', () {
      final targets = buildTimeTargets(_row(clockIn: '09:00'));
      final values = {targets.first.key: 9 * 60 + 1};
      expect(buildEditTimesPayload(targets, values).clockInHHmm, '09:01');
    });
  });

  group('canSubmitEditTimes', () {
    final payload = const EditTimesPayload(clockInHHmm: '09:03');

    test('변경 + 사유 있어야 저장 가능', () {
      expect(canSubmitEditTimes(payload, 'Wrong time recorded'), isTrue);
    });
    test('사유 없으면 불가', () {
      expect(canSubmitEditTimes(payload, '   '), isFalse);
    });
    test('변경 없으면 불가', () {
      expect(canSubmitEditTimes(const EditTimesPayload(), 'reason'), isFalse);
    });
  });

  group('changeHint', () {
    test('빠르게/늦게 + 시간 단위', () {
      expect(changeHint(540, 533), '7m earlier than recorded');
      expect(changeHint(540, 547), '7m later than recorded');
      expect(changeHint(540, 640), '1h 40m later than recorded');
    });
    test('변경 없으면 null', () {
      expect(changeHint(540, 540), isNull);
    });
  });

  group('shortBreakLabel', () {
    test('레거시 타입도 읽는다', () {
      expect(shortBreakLabel('unpaid_meal'), 'Meal');
      expect(shortBreakLabel('unpaid_long'), 'Meal');
      expect(shortBreakLabel('paid_10min'), '10-min');
      expect(shortBreakLabel('paid_short'), '10-min');
      expect(shortBreakLabel('mystery'), 'Break');
    });
  });
}
