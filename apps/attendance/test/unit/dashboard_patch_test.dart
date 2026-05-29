/// AttendanceDashboardNotifier.patchStaffByUserId — Issue 3 트랙 A.
///
/// state.staff 에 있는 user 의 row 만 replace, 나머지는 동일 reference 유지.
/// 없는 user 는 무시 (안전망).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/attendance_dashboard_provider.dart';

TodayStaffRow _row(String userId, String status, {String? name}) {
  return TodayStaffRow(
    userId: userId,
    userName: name ?? userId,
    scheduleId: null,
    scheduledStart: null,
    scheduledEnd: null,
    scheduledStartDisplay: null,
    scheduledEndDisplay: null,
    clockIn: null,
    clockOut: null,
    clockInDisplay: null,
    clockOutDisplay: null,
    status: status,
    currentBreak: null,
    paidBreakMinutes: 0,
    unpaidBreakMinutes: 0,
  );
}

void main() {
  group('patchStaffByUserId', () {
    test('해당 user row 만 교체, 다른 row 는 동일 reference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      final alice = _row('u1', 'upcoming', name: 'Alice');
      final bob = _row('u2', 'working', name: 'Bob');
      // 초기 state 주입
      notifier.state = notifier.state.copyWith(staff: [alice, bob]);

      final alicePatched = _row('u1', 'working', name: 'Alice');
      notifier.patchStaffByUserId(alicePatched);

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.length, 2);
      expect(after[0].status, 'working');
      expect(identical(after[1], bob), true,
          reason: 'Bob row 는 동일 reference 유지');
    });

    test('user 없는 row 는 무시 (state 변경 없음)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      final alice = _row('u1', 'upcoming');
      notifier.state = notifier.state.copyWith(staff: [alice]);

      final stranger = _row('u-unknown', 'working');
      notifier.patchStaffByUserId(stranger);

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.length, 1);
      expect(after[0].userId, 'u1');
      expect(after[0].status, 'upcoming');
    });

    test('빈 staff list 에 patch → 변경 없음', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      notifier.patchStaffByUserId(_row('u1', 'working'));

      expect(container.read(attendanceDashboardProvider).staff, isEmpty);
    });
  });
}
