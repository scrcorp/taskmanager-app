/// Unit tests — 스케줄 시각의 `+1` 마커 (정책 D5-4).
///
/// 고정하려는 계약:
///   - 마커는 **시각마다** 붙는다. 예전처럼 범위 끝에 " (+1d)" 를 한 번만 붙이면
///     시작·휴게·종료 중 무엇이 다음 날인지 알 수 없다.
///   - 날짜 정보(start_at/operating_day)가 없으면 추측하지 않는다.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/schedule.dart';
import 'package:app/utils/date_utils.dart';

ScheduleEntry _entry(Map<String, dynamic> extra) => ScheduleEntry.fromJson({
      'id': 'e-1',
      'user_id': 'u-1',
      'user_name': 'Alice',
      'store_id': 's-1',
      'store_name': 'Store',
      'work_role_id': null,
      'work_role_name': 'Server',
      'operating_day': '2026-08-10',
      'created_at': '2026-08-01T00:00:00Z',
      ...extra,
    });

void main() {
  group('hmWithDayMarker', () {
    final day = DateTime(2026, 8, 10);

    test('영업일 당일이면 마커 없음', () {
      expect(hmWithDayMarker(DateTime(2026, 8, 10, 21, 0), day), '21:00');
    });

    test('다음 날이면 +1, 이틀 뒤면 +2', () {
      expect(hmWithDayMarker(DateTime(2026, 8, 11, 2, 0), day), '02:00 +1');
      expect(hmWithDayMarker(DateTime(2026, 8, 12, 2, 0), day), '02:00 +2');
    });

    test('datetime 이 없으면 fallback 문자열 그대로 (추측 금지)', () {
      expect(hmWithDayMarker(null, day, fallbackHm: '02:00'), '02:00');
      expect(hmWithDayMarker(null, day), isNull);
    });

    test('영업일을 모르면 마커를 붙이지 않는다', () {
      expect(hmWithDayMarker(DateTime(2026, 8, 11, 2, 0), null), '02:00');
    });
  });

  group('ScheduleEntry.timeRange', () {
    test('자정을 넘는 휴게·종료에 각각 마커가 붙는다', () {
      final e = _entry({
        'start_time': '21:00',
        'end_time': '02:00',
        'break_start_time': '23:30',
        'break_end_time': '00:00',
        'start_at': '2026-08-10T21:00',
        'end_at': '2026-08-11T02:00',
        'break_start_at': '2026-08-10T23:30',
        'break_end_at': '2026-08-11T00:00',
      });
      expect(e.timeRange, '21:00–23:30 · 00:00 +1–02:00 +1');
    });

    test('영업일 안에서 끝나면 마커가 없다', () {
      final e = _entry({
        'start_time': '09:00',
        'end_time': '17:00',
        'start_at': '2026-08-10T09:00',
        'end_at': '2026-08-10T17:00',
      });
      expect(e.timeRange, '09:00 – 17:00');
    });

    test('구 응답(HH:mm 만) 은 마커 없이 그대로 보여준다', () {
      final e = _entry({'start_time': '21:00', 'end_time': '02:00'});
      expect(e.timeRange, '21:00 – 02:00');
    });
  });
}
