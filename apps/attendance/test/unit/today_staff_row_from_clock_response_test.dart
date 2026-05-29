/// TodayStaffRow.fromClockResponse — Issue 3 트랙 A pure 매핑 검증.
///
/// build_response (clock action 응답) → TodayStaffRow 변환.
/// 핵심:
///   - effective_status 우선 (raw status fallback)
///   - breaks 배열에서 ended_at IS NULL row → currentBreak
///   - 누락 필드 안전 처리

import 'package:flutter_test/flutter_test.dart';
import 'package:attendance/providers/attendance_dashboard_provider.dart';

void main() {
  group('TodayStaffRow.fromClockResponse', () {
    test('effective_status 우선, raw status 무시', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'user_name': 'Alice',
        'schedule_id': 's1',
        'clock_in': '2026-05-28T09:05:00Z',
        'status': 'late',                  // raw DB status
        'effective_status': 'working',     // computed
      });
      expect(row.userId, 'u1');
      expect(row.userName, 'Alice');
      expect(row.scheduleId, 's1');
      expect(row.status, 'working',
          reason: 'effective_status 가 raw status 보다 우선');
    });

    test('effective_status 없으면 raw status fallback', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'user_name': 'Alice',
        'status': 'on_break',
      });
      expect(row.status, 'on_break');
    });

    test('status 둘 다 없으면 upcoming default', () {
      final row = TodayStaffRow.fromClockResponse({'user_id': 'u1'});
      expect(row.status, 'upcoming');
    });

    test('breaks 배열에서 ended_at IS NULL 인 row → currentBreak', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'user_name': 'Alice',
        'effective_status': 'on_break',
        'breaks': [
          {
            'break_type': 'paid_10min',
            'started_at': '2026-05-28T10:00:00Z',
            'ended_at': '2026-05-28T10:10:00Z',
          },
          {
            'break_type': 'unpaid_meal',
            'started_at': '2026-05-28T12:00:00Z',
            'ended_at': null,
          },
        ],
      });
      expect(row.currentBreak, isNotNull);
      expect(row.currentBreak!.breakType, 'unpaid_meal');
    });

    test('모든 breaks 종료됨 → currentBreak null', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'effective_status': 'clocked_out',
        'breaks': [
          {
            'break_type': 'paid_10min',
            'started_at': '2026-05-28T10:00:00Z',
            'ended_at': '2026-05-28T10:10:00Z',
          },
        ],
      });
      expect(row.currentBreak, isNull);
    });

    test('breaks 키 없음 → currentBreak null', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'effective_status': 'working',
      });
      expect(row.currentBreak, isNull);
    });

    test('clock_in/clock_out + display 필드 그대로 통과', () {
      final row = TodayStaffRow.fromClockResponse({
        'user_id': 'u1',
        'clock_in': '2026-05-28T09:00:00Z',
        'clock_in_display': '09:00',
        'clock_out': '2026-05-28T17:00:00Z',
        'clock_out_display': '17:00',
        'effective_status': 'clocked_out',
      });
      expect(row.clockIn?.toIso8601String(), startsWith('2026-05-28T09:00'));
      expect(row.clockInDisplay, '09:00');
      expect(row.clockOutDisplay, '17:00');
    });

    test('paid/unpaid break minutes 0 default', () {
      final row = TodayStaffRow.fromClockResponse({'user_id': 'u1'});
      expect(row.paidBreakMinutes, 0);
      expect(row.unpaidBreakMinutes, 0);
    });
  });
}
