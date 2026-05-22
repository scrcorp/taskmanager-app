/// Unit tests — AttendanceAction enum extension (pure logic / no Flutter).
///
/// [작성됨] — Phase 4 (인프라 self-validation)
/// - AttendanceActionX.apiKey: 5 enum → 4 endpoint key 매핑 (break_short_paid /
///   break_long_unpaid 둘 다 'break-start' 로 매핑되는 분기 검증)
/// - AttendanceActionX.breakType: break_start 액션 2종 → 'paid_10min' /
///   'unpaid_meal', 그 외 → null
///
/// [작성 필요] — 추후
/// - localizedLabel (AppL10n 의존, mock 또는 fake l10n 필요)

import 'package:attendance/screens/attendance/attendance_main_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceActionX.apiKey', () {
    test('clockIn → "clock-in"', () {
      expect(AttendanceAction.clockIn.apiKey, 'clock-in');
    });

    test('clockOut → "clock-out"', () {
      expect(AttendanceAction.clockOut.apiKey, 'clock-out');
    });

    test('breakShortPaid → "break-start"', () {
      expect(AttendanceAction.breakShortPaid.apiKey, 'break-start');
    });

    test('breakLongUnpaid → "break-start"', () {
      // 휴게 종류는 break_type 으로 분리. action 자체는 단일.
      expect(AttendanceAction.breakLongUnpaid.apiKey, 'break-start');
    });

    test('breakEnd → "break-end"', () {
      expect(AttendanceAction.breakEnd.apiKey, 'break-end');
    });
  });

  group('AttendanceActionX.breakType', () {
    test('breakShortPaid → "paid_10min"', () {
      expect(AttendanceAction.breakShortPaid.breakType, 'paid_10min');
    });

    test('breakLongUnpaid → "unpaid_meal"', () {
      expect(AttendanceAction.breakLongUnpaid.breakType, 'unpaid_meal');
    });

    test('clockIn → null', () {
      expect(AttendanceAction.clockIn.breakType, isNull);
    });

    test('clockOut → null', () {
      expect(AttendanceAction.clockOut.breakType, isNull);
    });

    test('breakEnd → null', () {
      expect(AttendanceAction.breakEnd.breakType, isNull);
    });
  });
}
