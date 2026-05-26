/// IdentifyResponse.fromJson unit tests — Phase 5 Stage H-2c.

import 'package:attendance/models/identify_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdentifyResponse.fromJson', () {
    test('전체 정상 응답', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Marcus',
        'today_status': 'working',
      });
      expect(r.userId, 'u1');
      expect(r.userName, 'Marcus');
      expect(r.todayStatus, 'working');
      expect(r.currentBreak, isNull);
    });

    test('today_status null (no shift)', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Marcus',
        'today_status': null,
      });
      expect(r.todayStatus, isNull);
    });

    test('user_id 빠지면 "" fallback', () {
      final r = IdentifyResponse.fromJson({
        'user_name': 'Marcus',
        'today_status': 'working',
      });
      expect(r.userId, '');
    });

    test('user_name 빠지면 "" fallback', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'today_status': 'working',
      });
      expect(r.userName, '');
    });

    test('current_break Map 이면 parsing', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Marcus',
        'today_status': 'on_break',
        'current_break': {
          'started_at': '2026-05-22T12:00:00Z',
          'break_type': 'unpaid_meal',
        },
      });
      expect(r.currentBreak, isNotNull);
      expect(r.currentBreak!.breakType, 'unpaid_meal');
    });

    test('current_break null/missing 이면 currentBreak null', () {
      final r1 = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'M',
        'today_status': 'on_break',
        'current_break': null,
      });
      expect(r1.currentBreak, isNull);
      final r2 = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'M',
        'today_status': 'on_break',
      });
      expect(r2.currentBreak, isNull);
    });

    test('scheduled_end ISO 문자열 → DateTime parsing', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'M',
        'today_status': 'working',
        'scheduled_end': '2026-05-22T17:00:00Z',
      });
      expect(r.scheduledEnd, isNotNull);
      expect(r.scheduledEnd!.toUtc().hour, 17);
    });

    test('scheduled_end null/missing/invalid → null', () {
      expect(
        IdentifyResponse.fromJson({'user_id': 'u', 'user_name': 'M', 'today_status': 'working'}).scheduledEnd,
        isNull,
      );
      expect(
        IdentifyResponse.fromJson({
          'user_id': 'u', 'user_name': 'M', 'today_status': 'working',
          'scheduled_end': null,
        }).scheduledEnd,
        isNull,
      );
      expect(
        IdentifyResponse.fromJson({
          'user_id': 'u', 'user_name': 'M', 'today_status': 'working',
          'scheduled_end': 'not-a-date',
        }).scheduledEnd,
        isNull,
      );
    });

    test('non-String 값들도 toString 으로 fallback', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 12345,
        'user_name': 'M',
        'today_status': 'working',
      });
      expect(r.userId, '12345');
    });
  });
}
