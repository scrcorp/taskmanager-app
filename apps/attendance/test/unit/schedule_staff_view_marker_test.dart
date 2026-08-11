/// Unit tests — ScheduleStaffView 의 `+1` 마커 (D5-4).
///
/// 고정하려는 계약: 영업일 라벨과 달력 날짜가 다른 시각에만 마커가 붙고,
/// 날짜 정보(start_at/end_at/operating_day)가 없으면 **추측하지 않는다**.
/// 서버가 이 세 값을 이미 주고 있는데 앱이 파싱만 하고 버리던 것을 되살린 것이다.

import 'package:attendance/models/schedule_staff_view.dart';
import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AdminScheduleRow _row({
  String? startHHmm,
  String? endHHmm,
  DateTime? startAt,
  DateTime? endAt,
  DateTime? operatingDay,
}) =>
    AdminScheduleRow(
      scheduleId: 's-1',
      userId: 'u-1',
      userName: 'Alice',
      workRoleId: null,
      workRoleName: null,
      shiftName: null,
      positionName: null,
      startHHmm: startHHmm,
      endHHmm: endHHmm,
      startAt: startAt,
      endAt: endAt,
      operatingDay: operatingDay,
      status: 'confirmed',
      attendanceId: null,
      attendanceStatus: null,
      clockInDisplay: null,
      clockOutDisplay: null,
    );

void main() {
  test('영업일 안에서 끝나면 마커 없음', () {
    final v = _row(
      startHHmm: '10:00',
      endHHmm: '18:00',
      startAt: DateTime(2026, 8, 10, 10),
      endAt: DateTime(2026, 8, 10, 18),
      operatingDay: DateTime(2026, 8, 10),
    ).toView();
    expect(v.scheduledStartLabel, '10:00');
    expect(v.scheduledEndLabel, '18:00');
  });

  test('자정을 넘긴 종료에만 +1', () {
    final v = _row(
      startHHmm: '21:00',
      endHHmm: '02:30',
      startAt: DateTime(2026, 8, 10, 21),
      endAt: DateTime(2026, 8, 11, 2, 30),
      operatingDay: DateTime(2026, 8, 10),
    ).toView();
    expect(v.scheduledStartLabel, '21:00');
    expect(v.scheduledEndLabel, '02:30 +1');
  });

  test('새벽조는 시작에도 +1 (영업일 라벨은 전날)', () {
    final v = _row(
      startHHmm: '01:00',
      endHHmm: '05:00',
      startAt: DateTime(2026, 8, 11, 1),
      endAt: DateTime(2026, 8, 11, 5),
      operatingDay: DateTime(2026, 8, 10),
    ).toView();
    expect(v.scheduledStartLabel, '01:00 +1');
    expect(v.scheduledEndLabel, '05:00 +1');
  });

  test('날짜 정보가 없으면 마커를 추측하지 않는다', () {
    final v = _row(startHHmm: '21:00', endHHmm: '02:30').toView();
    expect(v.scheduledStartLabel, '21:00');
    expect(v.scheduledEndLabel, '02:30');
  });

  test('시각 자체가 없으면 null', () {
    final v = _row(operatingDay: DateTime(2026, 8, 10)).toView();
    expect(v.scheduledStartLabel, isNull);
    expect(v.scheduledEndLabel, isNull);
  });
}
