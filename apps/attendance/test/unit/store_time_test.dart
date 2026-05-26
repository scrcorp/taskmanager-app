/// store_time unit tests — Phase 5 Stage K 보강.

import 'package:attendance/utils/store_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('toStoreClock', () {
    test('offsetMinutes null → input 그대로 (fallback: device local 시간)', () {
      final input = DateTime.utc(2026, 5, 26, 1, 0); // 한국 KST 면 10:00
      final out = toStoreClock(input, null);
      expect(out, input);
    });

    test('offsetMinutes 0 → UTC wall-clock 그대로', () {
      final utcNow = DateTime.utc(2026, 5, 26, 1, 0); // 01:00 UTC
      final out = toStoreClock(utcNow, 0);
      expect(DateFormat('HH:mm').format(out), '01:00');
    });

    test('한국 KST 오전 10시 (UTC 01:00) → LA PDT (-420) 18:00 표시', () {
      // 사용자 시나리오: 한국 오전 10시 = UTC 01:00 = LA PDT 18:00 (전날).
      // 단, DateTime 산수는 시점만 보므로 PDT 의 wall-clock 만 검증.
      final utcNow = DateTime.utc(2026, 5, 26, 1, 0);
      final out = toStoreClock(utcNow, -420); // PDT UTC-7
      // 01:00 UTC - 7h = 전날 18:00
      expect(DateFormat('HH:mm').format(out), '18:00');
      expect(DateFormat('yyyy-MM-dd').format(out), '2026-05-25');
    });

    test('KST (+540) — 한국 매장, 한국 device → 동일 시각', () {
      final utcNow = DateTime.utc(2026, 5, 26, 1, 0); // 한국 wall=10:00
      final out = toStoreClock(utcNow, 540);
      expect(DateFormat('HH:mm').format(out), '10:00');
      expect(DateFormat('yyyy-MM-dd').format(out), '2026-05-26');
    });

    test('30분 offset TZ (네팔 +345)', () {
      final utcNow = DateTime.utc(2026, 5, 26, 1, 0);
      final out = toStoreClock(utcNow, 345); // 5h45m
      expect(DateFormat('HH:mm').format(out), '06:45');
    });

    test('자정 경계 (UTC 23:30 + +90 → 다음 날 01:00)', () {
      final utcNow = DateTime.utc(2026, 5, 26, 23, 30);
      final out = toStoreClock(utcNow, 90);
      expect(DateFormat('yyyy-MM-dd HH:mm').format(out), '2026-05-27 01:00');
    });
  });
}
