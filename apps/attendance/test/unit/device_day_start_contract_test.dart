/// 기기 정보의 **영업일 경계 필드 계약** 고정.
///
/// 서버는 `/device/me` 응답에 `store_day_start_times` 로 요일 7키를 전부 채워 내려준다
/// (server `app/utils/timezone.day_start_map`, `app/schemas/attendance_device.py`).
/// 앱이 다른 이름을 읽으면 값이 **조용히 null** 이 되고, 그러면 날짜 UI 가 꺼진 채
/// 아무 에러도 없이 예전 동작으로 돌아간다 — 실제로 이 트랙 구현 중 한 번 어긋났다.
/// 그래서 "필드 이름" 자체를 테스트로 못 박는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:attendance/providers/attendance_device_provider.dart';

void main() {
  group('DeviceInfo.fromJson — day start boundary', () {
    test('reads store_day_start_times (the server contract)', () {
      final info = DeviceInfo.fromJson({
        'status': 'ready',
        'store_day_start_times': {
          'mon': '11:00', 'tue': '11:00', 'wed': '11:00', 'thu': '11:00',
          'fri': '11:00', 'sat': '11:00', 'sun': '11:00',
        },
      });

      expect(info.dayStart, isNotNull,
          reason: 'store_day_start_times 를 못 읽으면 날짜 UI 가 조용히 꺼진다');
      // 경계 11:00 매장: 09:00 은 경계 이전, 17:00 은 이후.
      expect(info.dayStart!.minutesFor(DateTime(2026, 12, 7)), 11 * 60); // Mon
    });

    test('weekday keys are honored, not flattened to one value', () {
      final info = DeviceInfo.fromJson({
        'status': 'ready',
        'store_day_start_times': {
          'mon': '05:00', 'tue': '11:00', 'wed': '11:00', 'thu': '11:00',
          'fri': '11:00', 'sat': '11:00', 'sun': '11:00',
        },
      });

      expect(info.dayStart!.minutesFor(DateTime(2026, 12, 7)), 5 * 60);   // Mon
      expect(info.dayStart!.minutesFor(DateTime(2026, 12, 8)), 11 * 60);  // Tue
    });

    test('missing field leaves dayStart null (safe fallback, no date UI)', () {
      final info = DeviceInfo.fromJson({'status': 'ready'});
      expect(info.dayStart, isNull);
    });
  });
}
