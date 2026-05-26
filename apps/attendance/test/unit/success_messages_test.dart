/// success_messages unit tests — Phase 5 Recovery G.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/utils/success_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('successMessageFor — 5 액션 매핑', () {
    test('clockIn → CLOCKED IN / Have a great shift', () {
      final m = successMessageFor(AttendanceAction.clockIn, 'Marcus');
      expect(m.title, 'CLOCKED IN');
      expect(m.greeting, 'Have a great shift, Marcus!');
    });

    test('clockOut → CLOCKED OUT / Great work today', () {
      final m = successMessageFor(AttendanceAction.clockOut, 'Marcus');
      expect(m.title, 'CLOCKED OUT');
      expect(m.greeting, 'Great work today, Marcus!');
    });

    test('breakShortPaid → ON 10-MIN BREAK / See you in 10', () {
      final m = successMessageFor(AttendanceAction.breakShortPaid, 'Marcus');
      expect(m.title, 'ON 10-MIN BREAK');
      expect(m.greeting, 'See you in 10, Marcus!');
    });

    test('breakLongUnpaid → MEAL BREAK / Enjoy your meal', () {
      final m = successMessageFor(AttendanceAction.breakLongUnpaid, 'Marcus');
      expect(m.title, 'MEAL BREAK');
      expect(m.greeting, 'Enjoy your meal, Marcus!');
    });

    test('breakEnd → BACK TO WORK / Welcome back', () {
      final m = successMessageFor(AttendanceAction.breakEnd, 'Marcus');
      expect(m.title, 'BACK TO WORK');
      expect(m.greeting, 'Welcome back, Marcus!');
    });
  });

  group('successMessageFor — 이름 보간', () {
    test('다른 userName 으로 치환', () {
      final m = successMessageFor(AttendanceAction.clockIn, 'Sarah Kim');
      expect(m.greeting, 'Have a great shift, Sarah Kim!');
    });

    test('이름이 빈 문자열이어도 보간 (그대로 빈자리)', () {
      final m = successMessageFor(AttendanceAction.clockIn, '');
      expect(m.greeting, 'Have a great shift, !');
    });

    test('이름에 special char 가 있어도 그대로', () {
      final m = successMessageFor(AttendanceAction.clockIn, "O'Brien");
      expect(m.greeting, "Have a great shift, O'Brien!");
    });
  });

  group('successMessageFor — 모든 enum 값 매핑 보장', () {
    test('AttendanceAction.values 전부 호출 시 throw 없음', () {
      for (final a in AttendanceAction.values) {
        expect(() => successMessageFor(a, 'x'), returnsNormally, reason: a.name);
        final m = successMessageFor(a, 'x');
        expect(m.title, isNotEmpty);
        expect(m.greeting, contains('x'));
      }
    });
  });
}
