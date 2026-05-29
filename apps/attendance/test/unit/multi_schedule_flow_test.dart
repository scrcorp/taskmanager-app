/// Issue 8 — 다중 schedule flow transitions + IdentifyResponse 재구성 unit test.

import 'package:flutter_test/flutter_test.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/utils/main_flow_state.dart';
import 'package:attendance/utils/main_flow_transitions.dart' as flow;

IdentifyResponse _resp({required List<TodayAttendanceItem> atts, String? status}) {
  return IdentifyResponse(
    userId: 'u1',
    userName: 'Alice',
    todayStatus: status ?? (atts.isNotEmpty ? atts.first.status : null),
    todayAttendances: atts,
  );
}

TodayAttendanceItem _item(String scheduleId, String status) =>
    TodayAttendanceItem(scheduleId: scheduleId, status: status);

void main() {
  group('identifySucceeded 분기', () {
    test('0건 → confirming (primary 그대로)', () {
      final s = flow.identifySucceeded(
        MainFlowState.initial(),
        _resp(atts: [], status: null),
      );
      expect(s.stage, MainFlowStage.confirming);
      expect(s.user!.selectedScheduleId, isNull);
    });

    test('1건 → confirming + 그 schedule 자동 선택', () {
      final s = flow.identifySucceeded(
        MainFlowState.initial(),
        _resp(atts: [_item('s1', 'upcoming')]),
      );
      expect(s.stage, MainFlowStage.confirming);
      expect(s.user!.selectedScheduleId, 's1');
      expect(s.user!.todayStatus, 'upcoming');
    });

    test('2+건 → confirming + 우선순위 첫 번째(primary) 자동 선택 (picker 없음)', () {
      // server 가 우선순위 정렬해 보내므로 first 가 primary.
      final s = flow.identifySucceeded(
        MainFlowState.initial(),
        _resp(atts: [_item('s1', 'upcoming'), _item('s2', 'clocked_out')]),
      );
      expect(s.stage, MainFlowStage.confirming);
      expect(s.user!.selectedScheduleId, 's1'); // first 자동
      expect(s.user!.todayStatus, 'upcoming');
      expect(s.user!.todayAttendances.length, 2); // list 는 유지
    });
  });

  group('IdentifyResponse.withSelectedSchedule', () {
    test('todayStatus/scheduledEnd/currentBreak 를 선택 item 으로 교체', () {
      final resp = _resp(
        atts: [_item('s1', 'upcoming'), _item('s2', 'on_break')],
        status: 'upcoming',
      );
      final picked = resp.withSelectedSchedule(resp.todayAttendances[1]);
      expect(picked.selectedScheduleId, 's2');
      expect(picked.todayStatus, 'on_break');
      // 원본 user 정보 유지
      expect(picked.userId, 'u1');
      expect(picked.todayAttendances.length, 2);
    });
  });

  group('IdentifyResponse.fromJson — today_attendances', () {
    test('list 파싱', () {
      final resp = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Alice',
        'today_status': 'working',
        'today_attendances': [
          {'schedule_id': 's1', 'status': 'working', 'scheduled_start_display': '09:00'},
          {'schedule_id': 's2', 'status': 'clocked_out'},
        ],
      });
      expect(resp.todayAttendances.length, 2);
      expect(resp.todayAttendances[0].scheduleId, 's1');
      expect(resp.todayAttendances[0].scheduledStartDisplay, '09:00');
      expect(resp.todayAttendances[1].status, 'clocked_out');
    });

    test('today_attendances 누락 → 빈 list', () {
      final resp = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Alice',
        'today_status': null,
      });
      expect(resp.todayAttendances, isEmpty);
    });
  });
}
