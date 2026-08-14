/// AttendanceDashboardNotifier.patchStaffRow — Issue 3 트랙 A.
///
/// state.staff 에 있는 **shift** 의 row 만 replace, 나머지는 동일 reference 유지.
/// 매칭 shift 가 없으면 무시 (안전망).
/// row 는 사람이 아니라 shift 단위 — 하루 2 shift 인 사람도 각각 독립적으로 갱신돼야 한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/attendance_dashboard_provider.dart';

TodayStaffRow _row(String userId, String status, {String? name, String? scheduleId}) {
  return TodayStaffRow(
    userId: userId,
    userName: name ?? userId,
    scheduleId: scheduleId,
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
  group('patchStaffRow', () {
    test('해당 user row 만 교체, 다른 row 는 동일 reference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      final alice = _row('u1', 'upcoming', name: 'Alice');
      final bob = _row('u2', 'working', name: 'Bob');
      // 초기 state 주입
      notifier.state = notifier.state.copyWith(staff: [alice, bob]);

      final alicePatched = _row('u1', 'working', name: 'Alice');
      notifier.patchStaffRow(alicePatched);

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.length, 2);
      expect(after[0].status, 'working');
      expect(identical(after[1], bob), true,
          reason: 'Bob row 는 동일 reference 유지');
    });

    test('같은 user 의 2 shift — 고른 shift 만 교체된다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      final morning = _row('u1', 'no_show', name: 'Alice', scheduleId: 's-morning');
      final evening = _row('u1', 'upcoming', name: 'Alice', scheduleId: 's-evening');
      notifier.state = notifier.state.copyWith(staff: [morning, evening]);

      // 저녁 shift 로 clock-in — 오전 row 는 그대로 남아야 한다.
      notifier.patchStaffRow(
        _row('u1', 'working', name: 'Alice', scheduleId: 's-evening'),
      );

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.length, 2);
      expect(identical(after[0], morning), true,
          reason: '오전 shift 는 건드리지 않는다 (예전엔 첫 행이 교체됐다)');
      expect(after[1].status, 'working');
    });

    test('scheduleId 없는 row 는 userId 로 떨어진다 (하위호환)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      notifier.state = notifier.state.copyWith(staff: [_row('u1', 'upcoming')]);

      notifier.patchStaffRow(_row('u1', 'working'));

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.single.status, 'working');
    });

    test('user 없는 row 는 무시 (state 변경 없음)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      final alice = _row('u1', 'upcoming');
      notifier.state = notifier.state.copyWith(staff: [alice]);

      final stranger = _row('u-unknown', 'working');
      notifier.patchStaffRow(stranger);

      final after = container.read(attendanceDashboardProvider).staff;
      expect(after.length, 1);
      expect(after[0].userId, 'u1');
      expect(after[0].status, 'upcoming');
    });

    test('빈 staff list 에 patch → 변경 없음', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      notifier.patchStaffRow(_row('u1', 'working'));

      expect(container.read(attendanceDashboardProvider).staff, isEmpty);
    });
  });
}
