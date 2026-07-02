/// AttendanceDashboardNotifier.refresh() — ETag/304 delta polling (Task 3).
///
/// 304(Not Modified) 응답이면 기존 staff 리스트를 그대로 유지해야 하고,
/// 다음 호출의 If-None-Match 로 마지막 ETag 를 재사용해야 한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/services/attendance_device_service.dart';

/// getTodayStaff 호출을 가로채는 fake — 실제 네트워크 없이 200/304 시나리오 재현.
class _FakeAttendanceDeviceService extends AttendanceDeviceService {
  final List<TodayStaffResult> responses;
  int callCount = 0;
  final List<String?> receivedIfNoneMatch = [];

  _FakeAttendanceDeviceService(this.responses);

  @override
  Future<TodayStaffResult> getTodayStaff({String? ifNoneMatch}) async {
    receivedIfNoneMatch.add(ifNoneMatch);
    final result = responses[callCount.clamp(0, responses.length - 1)];
    callCount++;
    return result;
  }
}

void main() {
  group('AttendanceDashboardNotifier.refresh — ETag/304', () {
    test('200: staff 갱신 + etag 저장', () async {
      final fake = _FakeAttendanceDeviceService([
        TodayStaffResult(
          notModified: false,
          data: [
            {
              'user_id': 'u1',
              'user_name': 'Alice',
              'status': 'working',
            },
          ],
          etag: 'W/"etag-1"',
        ),
      ]);
      final container = ProviderContainer(overrides: [
        attendanceDeviceServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).refresh();

      final state = container.read(attendanceDashboardProvider);
      expect(state.staff.length, 1);
      expect(state.staff.first.userId, 'u1');
      expect(state.etag, 'W/"etag-1"');
      expect(state.loading, false);
      expect(fake.receivedIfNoneMatch, [null]); // 첫 호출은 저장된 etag 없음
    });

    test('304: staff 리스트 그대로 유지, etag 재확인, If-None-Match 로 마지막 etag 전달', () async {
      final aliceRow = {
        'user_id': 'u1',
        'user_name': 'Alice',
        'status': 'working',
      };
      final fake = _FakeAttendanceDeviceService([
        TodayStaffResult(notModified: false, data: [aliceRow], etag: 'W/"etag-1"'),
        TodayStaffResult.notModifiedResult(etag: 'W/"etag-1"'),
      ]);
      final container = ProviderContainer(overrides: [
        attendanceDeviceServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(attendanceDashboardProvider.notifier);
      await notifier.refresh(); // 200 — 초기 데이터
      final staffBeforeRef = container.read(attendanceDashboardProvider).staff;

      await notifier.refresh(); // 304 — 변경 없음

      final state = container.read(attendanceDashboardProvider);
      expect(state.staff.length, 1);
      expect(identical(state.staff, staffBeforeRef), true,
          reason: '304 응답이면 staff 리스트를 새로 만들지 않고 기존 reference 유지');
      expect(state.etag, 'W/"etag-1"');
      expect(state.loading, false);
      expect(state.error, isNull);
      // 두 번째 호출은 첫 응답의 etag 를 If-None-Match 로 보내야 함
      expect(fake.receivedIfNoneMatch, [null, 'W/"etag-1"']);
    });
  });
}
