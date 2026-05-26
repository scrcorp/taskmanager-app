/// flow_decisions unit tests — Phase 5 Stage H-1.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/utils/flow_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 5, 22, 12, 0); // 정오 기준

  group('remainingMinutesUntilScheduledEnd', () {
    test('scheduledEnd null → 0', () {
      expect(remainingMinutesUntilScheduledEnd(null, now), 0);
    });

    test('아직 종료 전 (30분 남음) → 30', () {
      final end = now.add(const Duration(minutes: 30));
      expect(remainingMinutesUntilScheduledEnd(end, now), 30);
    });

    test('아직 종료 전 (4시간 남음) → 240', () {
      final end = now.add(const Duration(hours: 4));
      expect(remainingMinutesUntilScheduledEnd(end, now), 240);
    });

    test('종료 시각 정확히 = now → 0', () {
      expect(remainingMinutesUntilScheduledEnd(now, now), 0);
    });

    test('종료 시각 이미 지남 → 0', () {
      final end = now.subtract(const Duration(minutes: 10));
      expect(remainingMinutesUntilScheduledEnd(end, now), 0);
    });

    test('소수 분 버림 (30분 30초 남음) → 30', () {
      final end = now.add(const Duration(minutes: 30, seconds: 30));
      expect(remainingMinutesUntilScheduledEnd(end, now), 30);
    });
  });

  group('shouldShowEarlyClockOutDialog', () {
    test('clock_in → false', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockIn,
          scheduledEnd: now.add(const Duration(hours: 4)),
          now: now,
        ),
        false,
      );
    });

    test('breakShortPaid / breakLongUnpaid / breakEnd → false', () {
      for (final a in [
        AttendanceAction.breakShortPaid,
        AttendanceAction.breakLongUnpaid,
        AttendanceAction.breakEnd,
      ]) {
        expect(
          shouldShowEarlyClockOutDialog(
            action: a,
            scheduledEnd: now.add(const Duration(hours: 4)),
            now: now,
          ),
          false,
          reason: a.name,
        );
      }
    });

    test('clock_out + scheduledEnd null → false', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: null,
          now: now,
        ),
        false,
      );
    });

    test('clock_out + 정상 시간 (4분 남음, threshold=5) → false', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(minutes: 4)),
          now: now,
        ),
        false,
      );
    });

    test('clock_out + threshold 정확 (5분 남음) → false (초과해야 early)', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(minutes: 5)),
          now: now,
        ),
        false,
      );
    });

    test('clock_out + threshold 초과 (6분 남음) → true', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(minutes: 6)),
          now: now,
        ),
        true,
      );
    });

    test('clock_out + 한참 일찍 (3시간 남음) → true', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(hours: 3)),
          now: now,
        ),
        true,
      );
    });

    test('clock_out + 종료 시각 이미 지남 → false', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        false,
      );
    });

    test('custom threshold (10분) — 8분 남음 → false', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(minutes: 8)),
          now: now,
          thresholdMinutes: 10,
        ),
        false,
      );
    });

    test('custom threshold (10분) — 12분 남음 → true', () {
      expect(
        shouldShowEarlyClockOutDialog(
          action: AttendanceAction.clockOut,
          scheduledEnd: now.add(const Duration(minutes: 12)),
          now: now,
          thresholdMinutes: 10,
        ),
        true,
      );
    });
  });

  group('shouldShowTipEntry', () {
    test('clock_out → true', () {
      expect(shouldShowTipEntry(AttendanceAction.clockOut), true);
    });

    test('clock_in / breaks → false', () {
      expect(shouldShowTipEntry(AttendanceAction.clockIn), false);
      expect(shouldShowTipEntry(AttendanceAction.breakShortPaid), false);
      expect(shouldShowTipEntry(AttendanceAction.breakLongUnpaid), false);
      expect(shouldShowTipEntry(AttendanceAction.breakEnd), false);
    });
  });

  group('isClockOutFlow', () {
    test('clock_out → true', () {
      expect(isClockOutFlow(AttendanceAction.clockOut), true);
    });

    test('나머지 → false', () {
      for (final a in [
        AttendanceAction.clockIn,
        AttendanceAction.breakShortPaid,
        AttendanceAction.breakLongUnpaid,
        AttendanceAction.breakEnd,
      ]) {
        expect(isClockOutFlow(a), false, reason: a.name);
      }
    });
  });
}
