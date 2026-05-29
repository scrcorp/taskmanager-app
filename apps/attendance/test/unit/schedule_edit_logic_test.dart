/// Unit tests — schedule_edit_logic (Issue 10 Step 5: round5 / auto-end / hhmm).

import 'package:attendance/utils/schedule_edit_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('round5ToNow', () {
    test('5분 단위 반올림', () {
      expect(round5ToNow(DateTime(2026, 5, 29, 12, 52)), 12 * 60 + 50); // 12:52 → 12:50
      expect(round5ToNow(DateTime(2026, 5, 29, 12, 53)), 12 * 60 + 55); // 12:53 → 12:55
      expect(round5ToNow(DateTime(2026, 5, 29, 15, 22)), 15 * 60 + 20); // 15:22 → 15:20
    });
  });

  group('hhmmToMinutes / minutesToHHmm', () {
    test('왕복 변환', () {
      expect(hhmmToMinutes('09:30'), 570);
      expect(minutesToHHmm(570), '09:30');
      expect(minutesToHHmm(900), '15:00');
    });
    test('형식 이상 → null', () {
      expect(hhmmToMinutes(null), isNull);
      expect(hhmmToMinutes('abc'), isNull);
      expect(hhmmToMinutes('9'), isNull);
    });
  });

  group('defaultEndMinutes', () {
    test('Start + 5.5h', () {
      expect(defaultEndMinutes(570), 570 + 330); // 09:30 → 15:00
      expect(minutesToHHmm(defaultEndMinutes(round5ToNow(DateTime(2026, 5, 29, 12, 55)))), '18:25');
    });
    test('자정 넘으면 clamp (23:59)', () {
      expect(defaultEndMinutes(20 * 60), 1439); // 20:00 + 5.5h = 25:30 → 23:59
    });
  });

  group('clampMinutes', () {
    test('범위 제한', () {
      expect(clampMinutes(-5), 0);
      expect(clampMinutes(2000), 1439);
      expect(clampMinutes(600), 600);
    });
  });
}
