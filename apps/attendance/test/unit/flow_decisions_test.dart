/// flow_decisions unit tests — Phase 5 Stage H-1.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/providers/attendance_dashboard_provider.dart'
    show TodayStaffBreak;
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
    test('clock_out + 매장 설정 on → true', () {
      expect(
        shouldShowTipEntry(AttendanceAction.clockOut, tipEntryEnabled: true),
        true,
      );
    });

    test('clock_out 이어도 매장 설정 off 면 false (store 토글이 최종 결정)', () {
      expect(
        shouldShowTipEntry(AttendanceAction.clockOut, tipEntryEnabled: false),
        false,
      );
    });

    test('clock_in / breaks → 설정과 무관하게 false', () {
      for (final a in [
        AttendanceAction.clockIn,
        AttendanceAction.breakShortPaid,
        AttendanceAction.breakLongUnpaid,
        AttendanceAction.breakEnd,
      ]) {
        expect(shouldShowTipEntry(a, tipEntryEnabled: true), false);
        expect(shouldShowTipEntry(a, tipEntryEnabled: false), false);
      }
    });
  });

  group('shouldShowBreakReasonDialog', () {
    TodayStaffBreak breakOf(String type, int minutesAgo) => TodayStaffBreak(
          startedAt: now.subtract(Duration(minutes: minutesAgo)),
          breakType: type,
        );

    test('unpaid_meal 40분 → true (서버가 사유를 요구하는 구간)', () {
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.breakEnd,
          currentBreak: breakOf('unpaid_meal', 40),
          now: now,
        ),
        true,
      );
    });

    test('unpaid_meal 32분 → false (허용 범위)', () {
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.breakEnd,
          currentBreak: breakOf('unpaid_meal', 32),
          now: now,
        ),
        false,
      );
    });

    test('paid_10min 은 아무리 길어도 false (초과분 unpaid 처리)', () {
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.breakEnd,
          currentBreak: breakOf('paid_10min', 40),
          now: now,
        ),
        false,
      );
    });

    test('break_end 가 아니면 false', () {
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.clockOut,
          currentBreak: breakOf('unpaid_meal', 40),
          now: now,
        ),
        false,
      );
    });

    test('초가 섞인 경계 — 분 절삭(R2) 기준으로 판정해 서버와 일치', () {
      // 12:00:50 시작 → 12:35:10 종료. 실제 경과는 34분 20초라
      // 예전 방식(.inMinutes)은 34분으로 보고 모달을 안 띄웠지만,
      // 서버는 12:35 − 12:00 = 35분으로 보고 사유를 요구해 400 을 준다.
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.breakEnd,
          currentBreak: TodayStaffBreak(
            startedAt: DateTime(2026, 5, 22, 12, 0, 50),
            breakType: 'unpaid_meal',
          ),
          now: DateTime(2026, 5, 22, 12, 35, 10),
        ),
        true,
      );
    });

    test('열린 break 정보가 없으면 false (서버 판단에 맡김)', () {
      expect(
        shouldShowBreakReasonDialog(
          action: AttendanceAction.breakEnd,
          currentBreak: null,
          now: now,
        ),
        false,
      );
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
