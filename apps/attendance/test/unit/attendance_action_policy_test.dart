/// attendance_action_policy unit tests — Phase 5 Recovery D.
///
/// status × action × breakType × elapsed 매트릭스 전수 커버.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/utils/attendance_action_policy.dart';
import 'package:flutter_test/flutter_test.dart';

bool _allowed(
  String? status,
  AttendanceAction action, {
  String? breakType,
  int elapsed = 0,
}) =>
    isActionAllowed(
      todayStatus: status,
      action: action,
      currentBreakType: breakType,
      currentBreakElapsedMinutes: elapsed,
    );

String? _hint(
  String? status,
  AttendanceAction action, {
  String? breakType,
  int elapsed = 0,
}) =>
    breakLockedHint(
      todayStatus: status,
      action: action,
      currentBreakType: breakType,
      currentBreakElapsedMinutes: elapsed,
    );

void main() {
  group('isActionAllowed — todayStatus null', () {
    test('어떤 action 이든 false', () {
      for (final a in AttendanceAction.values) {
        expect(_allowed(null, a), false, reason: a.name);
      }
    });
  });

  group('isActionAllowed — upcoming/soon/late/no_show', () {
    for (final s in ['upcoming', 'soon', 'late', 'no_show']) {
      test('$s — Clock In 만 true, 나머지 false', () {
        expect(_allowed(s, AttendanceAction.clockIn), true);
        expect(_allowed(s, AttendanceAction.clockOut), false);
        expect(_allowed(s, AttendanceAction.breakShortPaid), false);
        expect(_allowed(s, AttendanceAction.breakLongUnpaid), false);
        expect(_allowed(s, AttendanceAction.breakEnd), false);
      });
    }
  });

  group('isActionAllowed — working', () {
    test('Clock Out / 10-min / Meal 허용', () {
      expect(_allowed('working', AttendanceAction.clockOut), true);
      expect(_allowed('working', AttendanceAction.breakShortPaid), true);
      expect(_allowed('working', AttendanceAction.breakLongUnpaid), true);
    });

    test('Clock In / End Break 비활성', () {
      expect(_allowed('working', AttendanceAction.clockIn), false);
      expect(_allowed('working', AttendanceAction.breakEnd), false);
    });
  });

  group('isActionAllowed — on_break + paid_10min', () {
    test('5m → End Break 비활성', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'paid_10min', elapsed: 5),
        false,
      );
    });

    test('10m → End Break 활성', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'paid_10min', elapsed: 10),
        true,
      );
    });

    test('15m (over) → End Break 활성 (초과분 unpaid 처리, 종료 자체는 가능)', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'paid_10min', elapsed: 15),
        true,
      );
    });
  });

  group('isActionAllowed — on_break + unpaid_meal', () {
    test('18m → End Break 비활성', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 18),
        false,
      );
    });

    test('30m → End Break 활성', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 30),
        true,
      );
    });

    test('32m (within) → End Break 활성', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 32),
        true,
      );
    });

    test('40m (requires reason) → End Break 활성 (사유는 dialog 에서)', () {
      expect(
        _allowed('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 40),
        true,
      );
    });
  });

  group('isActionAllowed — on_break Clock Out 항상 허용', () {
    test('5m unpaid → Clock Out 허용 (긴급)', () {
      expect(
        _allowed('on_break', AttendanceAction.clockOut, breakType: 'unpaid_meal', elapsed: 5),
        true,
      );
    });

    test('breakType null 이어도 Clock Out 허용', () {
      expect(_allowed('on_break', AttendanceAction.clockOut), true);
    });
  });

  group('isActionAllowed — on_break 기타 action 비활성', () {
    test('Clock In / Break-start 두 종류 모두 비활성', () {
      expect(_allowed('on_break', AttendanceAction.clockIn, breakType: 'unpaid_meal', elapsed: 32), false);
      expect(_allowed('on_break', AttendanceAction.breakShortPaid, breakType: 'unpaid_meal', elapsed: 32), false);
      expect(_allowed('on_break', AttendanceAction.breakLongUnpaid, breakType: 'unpaid_meal', elapsed: 32), false);
    });
  });

  group('isActionAllowed — on_break + breakType null', () {
    test('breakType null 이면 End Break 비활성 (정보 불충분)', () {
      expect(_allowed('on_break', AttendanceAction.breakEnd), false);
    });
  });

  group('isActionAllowed — clocked_out', () {
    test('모든 action 비활성', () {
      for (final a in AttendanceAction.values) {
        expect(_allowed('clocked_out', a), false, reason: a.name);
      }
    });
  });

  group('isActionAllowed — unknown status', () {
    test('"foo" → 모두 비활성', () {
      for (final a in AttendanceAction.values) {
        expect(_allowed('foo', a), false, reason: a.name);
      }
    });
  });

  group('breakLockedHint', () {
    test('breakEnd 가 아닌 action → null', () {
      expect(_hint('on_break', AttendanceAction.clockOut, breakType: 'unpaid_meal', elapsed: 10), isNull);
    });

    test('todayStatus 가 on_break 가 아니면 → null', () {
      expect(_hint('working', AttendanceAction.breakEnd), isNull);
    });

    test('on_break + breakType null → null (정보 없음)', () {
      expect(_hint('on_break', AttendanceAction.breakEnd), isNull);
    });

    test('on_break + paid_10min + 5m → "Wait 5m more"', () {
      expect(
        _hint('on_break', AttendanceAction.breakEnd, breakType: 'paid_10min', elapsed: 5),
        'Wait 5m more',
      );
    });

    test('on_break + unpaid_meal + 18m → "Wait 12m more"', () {
      expect(
        _hint('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 18),
        'Wait 12m more',
      );
    });

    test('on_break + paid_10min + 10m (이미 활성) → null', () {
      expect(
        _hint('on_break', AttendanceAction.breakEnd, breakType: 'paid_10min', elapsed: 10),
        isNull,
      );
    });

    test('on_break + unpaid_meal + 30m (이미 활성) → null', () {
      expect(
        _hint('on_break', AttendanceAction.breakEnd, breakType: 'unpaid_meal', elapsed: 30),
        isNull,
      );
    });
  });
}
