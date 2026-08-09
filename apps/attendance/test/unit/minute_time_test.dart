import 'package:attendance/utils/minute_time.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime t(int hour, int minute, [int second = 0, int ms = 0]) =>
    DateTime.utc(2026, 8, 8, hour, minute, second, ms);

void main() {
  group('floorToMinute', () {
    test('drops seconds and milliseconds', () {
      expect(floorToMinute(t(18, 1, 59, 999)), t(18, 1));
    });

    test('keeps exact minute', () {
      expect(floorToMinute(t(18, 1)), t(18, 1));
    });

    test('preserves utc flag', () {
      expect(floorToMinute(t(18, 1, 30)).isUtc, isTrue);
      expect(floorToMinute(DateTime(2026, 8, 8, 18, 1, 30)).isUtc, isFalse);
    });
  });

  group('minutesBetween', () {
    test('truncates first, then subtracts (not floor of diff)', () {
      // 실제 30분 30초. 화면엔 22:26 – 22:57 로 보이므로 31 이어야 한다.
      expect(minutesBetween(t(22, 26, 50), t(22, 57, 20)), 31);
    });

    test('does not round up like the old console late calc', () {
      expect(minutesBetween(t(17, 30), t(18, 1, 40)), 31);
    });

    test('same minute different seconds is zero', () {
      expect(minutesBetween(t(18, 1, 5), t(18, 1, 55)), 0);
    });

    test('returns negative when end precedes start', () {
      expect(minutesBetween(t(18, 0), t(17, 30)), -30);
    });

    test('crosses midnight', () {
      expect(minutesBetween(t(22, 30, 40), t(22, 30, 40).add(const Duration(hours: 6))), 360);
    });
  });

  group('minutesBetweenClamped', () {
    test('clamps negative to zero', () {
      expect(minutesBetweenClamped(t(18, 0), t(17, 30)), 0);
    });

    test('same as minutesBetween when positive', () {
      expect(minutesBetweenClamped(t(22, 26, 50), t(22, 57, 20)), 31);
    });
  });
}
