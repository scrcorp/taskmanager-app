/// ManageScheduleEditModal widget test.
///
/// 고정하려는 계약: **매니저가 안 건드린 시각은 PATCH 에 실리지 않는다.**
/// 워크인 스케줄은 실제 clock-in 시각(분 단위)으로 저장돼 있어서, 다른 항목만 고쳤는데
/// 시각까지 같이 전송되면 5분 grid 에 걸려 저장이 실패하거나 값이 조용히 반올림된다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/services/attendance_device_service.dart';
import 'package:attendance/widgets/manage_schedule_edit_modal.dart';

import '_test_helpers.dart';

class _FakeService extends AttendanceDeviceService {
  Map<String, dynamic>? lastUpdate;

  @override
  Future<List<Map<String, dynamic>>> manageListAssignableUsers() async => [
        {'user_id': 'u-1', 'full_name': 'Alice Kim', 'role_name': 'Staff'},
      ];

  @override
  Future<List<Map<String, dynamic>>> manageListWorkRoles() async => const [];

  @override
  Future<Map<String, dynamic>> manageUpdateSchedule({
    required String scheduleId,
    String? userId,
    String? workRoleId,
    String? startHHmm,
    String? endHHmm,
    String? operatingDay,
    String? startAt,
    String? endAt,
  }) async {
    lastUpdate = {
      'schedule_id': scheduleId,
      'user_id': userId,
      'start_time': startHHmm,
      'end_time': endHHmm,
    };
    return {'schedule_id': scheduleId};
  }
}

const _walkInRow = AdminScheduleRow(
  scheduleId: 's-1',
  userId: 'u-1',
  userName: 'Alice Kim',
  workRoleId: null,
  workRoleName: null,
  shiftName: null,
  positionName: null,
  startHHmm: '09:07', // 워크인 — 5분 grid 밖
  endHHmm: '14:37',
  status: 'confirmed',
  attendanceId: null,
  attendanceStatus: null,
  clockInDisplay: null,
  clockOutDisplay: null,
);

Future<void> _openModal(WidgetTester tester, _FakeService service) async {
  await useTabletSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [attendanceDeviceServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: Scaffold(body: ManageScheduleEditModal(existing: _walkInRow)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('시각을 안 건드리면 PATCH 에 start/end 가 빠진다 (워크인 값 보존)', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(service.lastUpdate, isNotNull);
    expect(service.lastUpdate!['start_time'], isNull);
    expect(service.lastUpdate!['end_time'], isNull);
    expect(service.lastUpdate!['user_id'], 'u-1');
  });

  testWidgets('시각을 직접 고치면 그 값이 5분 단위로 실린다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service);

    // 시작 시각 휠(첫 TimeWheel 의 분 컬럼)을 굴려 다른 눈금 선택
    final minuteColumns = find.byType(ListWheelScrollView);
    await tester.drag(minuteColumns.at(1), const Offset(0, -90));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final start = service.lastUpdate!['start_time'] as String?;
    expect(start, isNotNull);
    expect(int.parse(start!.split(':')[1]) % 5, 0);
  });
}
