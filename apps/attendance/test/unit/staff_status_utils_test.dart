/// Unit tests — staff_status_utils (pure logic, no DB/IO).
///
/// [작성됨] — Phase 5 Stage A
/// - classifySection (5+ status → section)
/// - statusLabel (alias 매핑)
/// - breakLabel (paid/unpaid + legacy dual-read)
/// - staffBlockSubline (status 별 1줄 서브)
/// - breakProgress (paid/unpaid × 4 분기 = 7 케이스 + edge)

import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/utils/staff_status_utils.dart';
import 'package:flutter_test/flutter_test.dart';

TodayStaffRow _row({
  String status = 'working',
  String? clockInDisplay,
  String? clockOutDisplay,
  String? scheduledStartDisplay,
  TodayStaffBreak? currentBreak,
}) {
  return TodayStaffRow(
    userId: 'u1',
    userName: 'Test User',
    scheduleId: null,
    scheduledStart: null,
    scheduledEnd: null,
    scheduledStartDisplay: scheduledStartDisplay,
    scheduledEndDisplay: null,
    clockIn: null,
    clockOut: null,
    clockInDisplay: clockInDisplay,
    clockOutDisplay: clockOutDisplay,
    status: status,
    currentBreak: currentBreak,
    paidBreakMinutes: 0,
    unpaidBreakMinutes: 0,
  );
}

void main() {
  group('classifySection', () {
    test('working / on_break → clockedIn', () {
      expect(classifySection('working'), StaffSection.clockedIn);
      expect(classifySection('on_break'), StaffSection.clockedIn);
    });

    test('upcoming / soon / late / no_show → notClockedIn', () {
      for (final s in ['upcoming', 'soon', 'late', 'no_show']) {
        expect(classifySection(s), StaffSection.notClockedIn, reason: s);
      }
    });

    test('clocked_out → completed', () {
      expect(classifySection('clocked_out'), StaffSection.completed);
    });

    test('cancelled / unknown → other', () {
      expect(classifySection('cancelled'), StaffSection.other);
      expect(classifySection('something_else'), StaffSection.other);
    });
  });

  group('statusLabel', () {
    test('known statuses', () {
      expect(statusLabel('working'), 'Working');
      expect(statusLabel('on_break'), 'On Break');
      expect(statusLabel('clocked_out'), 'Clocked Out');
      expect(statusLabel('no_show'), 'No-show');
    });

    test('unknown → returns input', () {
      expect(statusLabel('foo'), 'foo');
    });
  });

  group('breakLabel', () {
    test('paid_10min / paid_short (legacy) → 10-min', () {
      expect(breakLabel('paid_10min'), '10-min Break (paid)');
      expect(breakLabel('paid_short'), '10-min Break (paid)');
    });

    test('unpaid_meal / unpaid_long (legacy) → meal', () {
      expect(breakLabel('unpaid_meal'), 'Meal Break (unpaid)');
      expect(breakLabel('unpaid_long'), 'Meal Break (unpaid)');
    });

    test('unknown → "On Break" fallback', () {
      expect(breakLabel('weird_type'), 'On Break');
    });
  });

  group('staffBlockSubline', () {
    final fixedNow = DateTime(2026, 5, 22, 12, 0);

    test('working with clockInDisplay → "In HH:MM"', () {
      final row = _row(status: 'working', clockInDisplay: '09:02');
      expect(staffBlockSubline(row, now: fixedNow), 'In 09:02');
    });

    test('working without clockInDisplay → "Working"', () {
      expect(staffBlockSubline(_row(status: 'working'), now: fixedNow), 'Working');
    });

    test('on_break with currentBreak → "Break Nm"', () {
      final br = TodayStaffBreak(
        startedAt: fixedNow.subtract(const Duration(minutes: 18)),
        breakType: 'unpaid_meal',
      );
      final row = _row(status: 'on_break', currentBreak: br);
      expect(staffBlockSubline(row, now: fixedNow), 'Break 18m');
    });

    test('on_break without currentBreak → "On Break"', () {
      expect(staffBlockSubline(_row(status: 'on_break'), now: fixedNow), 'On Break');
    });

    test('clocked_out with clockOutDisplay → "Out HH:MM"', () {
      final row = _row(status: 'clocked_out', clockOutDisplay: '14:05');
      expect(staffBlockSubline(row, now: fixedNow), 'Out 14:05');
    });

    test('other status falls back to scheduled_start_display', () {
      final row = _row(status: 'upcoming', scheduledStartDisplay: '14:00');
      expect(staffBlockSubline(row, now: fixedNow), '14:00');
    });

    test('other status with no schedule display → "—"', () {
      expect(staffBlockSubline(_row(status: 'upcoming'), now: fixedNow), '—');
    });
  });

  group('breakProgress — paid_10min', () {
    test('5m → tooShort, canEndBreak=false, remaining=5', () {
      final p = breakProgress('paid_10min', 5);
      expect(p.state, BreakState.tooShort);
      expect(p.canEndBreak, false);
      expect(p.remainingMinutes, 5);
    });

    test('10m → within, canEndBreak=true', () {
      final p = breakProgress('paid_10min', 10);
      expect(p.state, BreakState.within);
      expect(p.canEndBreak, true);
    });

    test('15m → overAllowance, hint mentions unpaid', () {
      final p = breakProgress('paid_10min', 15);
      expect(p.state, BreakState.overAllowance);
      expect(p.canEndBreak, true);
      expect(p.hint, contains('5m'));
      expect(p.hint, contains('unpaid'));
    });
  });

  group('breakProgress — unpaid_meal', () {
    test('18m → tooShort, remaining=12', () {
      final p = breakProgress('unpaid_meal', 18);
      expect(p.state, BreakState.tooShort);
      expect(p.canEndBreak, false);
      expect(p.remainingMinutes, 12);
    });

    test('32m → within (30~35 allowance)', () {
      final p = breakProgress('unpaid_meal', 32);
      expect(p.state, BreakState.within);
      expect(p.canEndBreak, true);
    });

    test('35m → requiresReason', () {
      final p = breakProgress('unpaid_meal', 35);
      expect(p.state, BreakState.requiresReason);
      expect(p.canEndBreak, true);
      expect(p.hint, contains('reason'));
    });

    test('40m → requiresReason', () {
      final p = breakProgress('unpaid_meal', 40);
      expect(p.state, BreakState.requiresReason);
    });
  });
}
