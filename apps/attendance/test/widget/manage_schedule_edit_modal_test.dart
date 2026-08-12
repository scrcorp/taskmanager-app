/// ManageScheduleEditModal widget test.
///
/// 고정하려는 계약:
///   1. 저장은 **항상 시작·종료 둘 다** 보낸다(D7-3). 서버가 "달라진 값"만 검사하므로
///      부분 전송이 필요 없고, 한쪽만 보내면 영업일 번역이 스킵돼 새벽조 날짜가 틀어진다.
///      (워크인의 5분 비배수 값도 그대로 되보내면 되며, 서버가 면제해 준다)
///   2. 409 `SCHEDULE_WARNINGS_UNCONFIRMED` → 경고를 보여주고, 확인해야 `force:true` 재요청.
///      메시지 문자열이 아니라 **최상위 code** 로만 분기한다.
///   3. 자정을 넘겨도 종료가 23:59 로 잘리지 않는다.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/services/attendance_device_service.dart';
import 'package:attendance/utils/schedule_codes.dart';
import 'package:attendance/widgets/manage_schedule_edit_modal.dart';

import '_test_helpers.dart';

class _FakeService extends AttendanceDeviceService {
  final List<Map<String, dynamic>> updates = [];
  final List<Map<String, dynamic>> creates = [];

  /// 몇 번째 호출까지 409 를 던질지 (경고 미확인 시뮬레이션).
  int warnUntilCall = 0;
  int _calls = 0;

  @override
  Future<List<Map<String, dynamic>>> manageListAssignableUsers() async => [
        {'user_id': 'u-1', 'full_name': 'Alice Kim', 'role_name': 'Staff'},
      ];

  @override
  Future<List<Map<String, dynamic>>> manageListWorkRoles() async => const [];

  DioException _warningsUnconfirmed() => DioException(
        requestOptions: RequestOptions(path: '/attendance/manage/schedules'),
        response: Response(
          requestOptions: RequestOptions(path: '/attendance/manage/schedules'),
          statusCode: 409,
          data: {
            'detail': {
              'code': kScheduleWarningsUnconfirmed,
              'message': 'This employee already has an overlapping schedule.',
              'warnings': [
                {'code': kOverlappingSchedule, 'params': {'user_id': 'u-1'}},
              ],
              'retry': {'force': true},
            }
          },
        ),
      );

  /// 저장 시 서버가 400 SCHEDULE_INVALID + 이 코드들로 응답한다고 가정.
  List<String> failWithErrorCodes = const [];

  @override
  Future<Map<String, dynamic>> manageUpdateSchedule({
    required String scheduleId,
    String? userId,
    String? workRoleId,
    String? startHHmm,
    String? endHHmm,
    String? breakStartHHmm,
    String? breakEndHHmm,
    String? operatingDay,
    String? startAt,
    String? endAt,
    bool force = false,
  }) async {
    _calls++;
    updates.add({
      'schedule_id': scheduleId,
      'user_id': userId,
      'start_time': startHHmm,
      'end_time': endHHmm,
      // 휴게는 **키가 항상 실려야** 한다. null 이면 '삭제'라는 뜻이라, 키 자체가
      // 빠지는 것(=구버전 호환 '유지')과 구분해서 기록한다.
      'break_start_time': breakStartHHmm,
      'break_end_time': breakEndHHmm,
      'force': force,
    });
    if (failWithErrorCodes.isNotEmpty) throw _invalid(failWithErrorCodes);
    if (_calls <= warnUntilCall) throw _warningsUnconfirmed();
    return {'schedule_id': scheduleId};
  }

  @override
  Future<Map<String, dynamic>> manageCreateSchedule({
    required String userId,
    String? workRoleId,
    required String startHHmm,
    required String endHHmm,
    String? breakStartHHmm,
    String? breakEndHHmm,
    String? operatingDay,
    String? startAt,
    String? endAt,
    bool force = false,
  }) async {
    _calls++;
    creates.add({
      'user_id': userId,
      'start_time': startHHmm,
      'end_time': endHHmm,
      'break_start_time': breakStartHHmm,
      'break_end_time': breakEndHHmm,
      'operating_day': operatingDay,
      'force': force,
    });
    if (failWithErrorCodes.isNotEmpty) throw _invalid(failWithErrorCodes);
    if (_calls <= warnUntilCall) throw _warningsUnconfirmed();
    return {'schedule_id': 's-new'};
  }

  DioException _invalid(List<String> codes) => DioException(
        requestOptions: RequestOptions(path: '/attendance/manage/schedules'),
        response: Response(
          requestOptions: RequestOptions(path: '/attendance/manage/schedules'),
          statusCode: 400,
          data: {
            'detail': {
              'code': kScheduleInvalid,
              'message': 'nope',
              'errors': [for (final c in codes) {'code': c, 'params': {}}],
              'warnings': const [],
            }
          },
        ),
      );
}

/// 워크인 — 시각이 5분 배수를 벗어나 있고, 자정을 넘는 새벽조.
final _walkInRow = AdminScheduleRow(
  scheduleId: 's-1',
  userId: 'u-1',
  userName: 'Alice Kim',
  workRoleId: null,
  workRoleName: null,
  shiftName: null,
  positionName: null,
  startHHmm: '21:07',
  endHHmm: '02:37',
  startAt: DateTime(2026, 8, 10, 21, 7),
  endAt: DateTime(2026, 8, 11, 2, 37),
  operatingDay: DateTime(2026, 8, 10),
  status: 'confirmed',
  attendanceId: null,
  attendanceStatus: null,
  clockInDisplay: null,
  clockOutDisplay: null,
);

/// 휴게가 있는 주간 근무 — 09:00~17:00, 12:00~12:30 휴게.
final _rowWithBreak = AdminScheduleRow(
  scheduleId: 's-2',
  userId: 'u-1',
  userName: 'Alice Kim',
  workRoleId: null,
  workRoleName: null,
  shiftName: null,
  positionName: null,
  startHHmm: '09:00',
  endHHmm: '17:00',
  breakStartHHmm: '12:00',
  breakEndHHmm: '12:30',
  startAt: DateTime(2026, 8, 10, 9, 0),
  endAt: DateTime(2026, 8, 10, 17, 0),
  breakStartAt: DateTime(2026, 8, 10, 12, 0),
  breakEndAt: DateTime(2026, 8, 10, 12, 30),
  operatingDay: DateTime(2026, 8, 10),
  status: 'confirmed',
  attendanceId: null,
  attendanceStatus: null,
  clockInDisplay: null,
  clockOutDisplay: null,
);

Future<void> _openModal(
  WidgetTester tester,
  _FakeService service, {
  AdminScheduleRow? existing,
  DateTime? operatingDay,
}) async {
  await useTabletSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [attendanceDeviceServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Scaffold(
          body: ManageScheduleEditModal(
            existing: existing,
            operatingDay: operatingDay,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('시각을 안 건드려도 시작·종료가 항상 실린다 (전체 전송)', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _walkInRow);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(service.updates, hasLength(1));
    // 워크인의 비배수 값이 그대로 되돌아간다 — 반올림해서 조용히 바꾸지 않는다.
    expect(service.updates.single['start_time'], '21:07');
    expect(service.updates.single['end_time'], '02:37');
    expect(service.updates.single['user_id'], 'u-1');
    expect(service.updates.single['force'], isFalse);
  });

  testWidgets('자정 넘김 표기 — 종료에 +1 마커가 붙는다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _walkInRow);

    expect(find.text('+1'), findsOneWidget);
    expect(find.textContaining('21:07 → 02:37 +1'), findsOneWidget);
  });

  testWidgets('길이 버튼 — 시작 고정, 종료가 따라 움직인다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _walkInRow);

    await tester.tap(find.text('+30m'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(service.updates.single['start_time'], '21:07'); // 시작은 저절로 안 움직인다
    expect(service.updates.single['end_time'], '03:07');
  });

  testWidgets('409 경고 → 확인하면 force:true 로 재요청', (tester) async {
    final service = _FakeService()..warnUntilCall = 1;
    await _openModal(tester, service, existing: _walkInRow);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // 경고 문구는 코드로 구성한다 (서버 message 문자열이 아님)
    expect(find.textContaining('overlapping shift'), findsOneWidget);

    await tester.tap(find.text('Save Anyway'));
    await tester.pumpAndSettle();

    expect(service.updates, hasLength(2));
    expect(service.updates.first['force'], isFalse);
    expect(service.updates.last['force'], isTrue);
  });

  testWidgets('409 경고 → 취소하면 저장하지 않는다', (tester) async {
    final service = _FakeService()..warnUntilCall = 1;
    await _openModal(tester, service, existing: _walkInRow);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();

    expect(service.updates, hasLength(1)); // 재요청 없음
    expect(find.text('Save Changes'), findsOneWidget); // 모달은 열린 채
  });

  testWidgets('휴게가 있는 스케줄 — 손대지 않아도 휴게가 그대로 실린다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _rowWithBreak);

    expect(find.textContaining('12:00 → 12:30'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(service.updates.single['break_start_time'], '12:00');
    expect(service.updates.single['break_end_time'], '12:30');
  });

  testWidgets('Remove Break → 휴게 두 키가 null 로 실린다 (= 삭제)', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _rowWithBreak);

    // 모달 본문은 스크롤 영역이라 휴게 행이 화면 밖일 수 있다.
    await tester.ensureVisible(find.text('Remove Break'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Break'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // 키는 있고 값만 null 이어야 한다. 키가 빠지면 서버는 "구버전이라 유지"로 읽어
    // 삭제가 조용히 무시된다(B7).
    final body = service.updates.single;
    expect(body.containsKey('break_start_time'), isTrue);
    expect(body['break_start_time'], isNull);
    expect(body['break_end_time'], isNull);
  });

  testWidgets('Add Break → 근무 안에 들어가고 저장에 실린다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, existing: _rowWithBreak);

    await tester.ensureVisible(find.text('Remove Break'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Break'));
    await tester.pumpAndSettle();
    expect(find.text('Add Break'), findsOneWidget);

    await tester.ensureVisible(find.text('Add Break'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Break'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // 09:00~17:00 한가운데 30분 → 12:45~13:15 (근무창 안).
    expect(service.updates.single['break_start_time'], '12:45');
    expect(service.updates.single['break_end_time'], '13:15');
  });

  testWidgets('PAY_PERIOD_LOCKED → 코드로 분기해 전용 안내 (force 버튼 없음)', (tester) async {
    final service = _FakeService()..failWithErrorCodes = [kPayPeriodLocked];
    await _openModal(tester, service, existing: _rowWithBreak);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Pay Period Closed'), findsOneWidget);
    expect(find.textContaining('Ask payroll to reopen it'), findsOneWidget);
    expect(find.text('Save Anyway'), findsNothing);
  });

  testWidgets('다른 영업일에서 생성 — operating_day 가 실린다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service, operatingDay: DateTime(2026, 8, 12));

    await tester.tap(find.text('Select staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Kim  ·  Staff').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Schedule'));
    await tester.pumpAndSettle();

    // 안 보내면 서버가 오늘로 앵커한다 — 화면과 다른 날에 만들어지는 사고.
    expect(service.creates.single['operating_day'], '2026-08-12');
  });

  testWidgets('신규 — 저녁 시작이어도 종료가 23:59 로 잘리지 않는다', (tester) async {
    final service = _FakeService();
    await _openModal(tester, service); // existing 없음 → 현재 시각 기준

    await tester.tap(find.text('Select staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Kim  ·  Staff').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Schedule'));
    await tester.pumpAndSettle();

    expect(service.creates, hasLength(1));
    final end = service.creates.single['end_time'] as String;
    expect(int.parse(end.split(':')[1]) % 5, 0, reason: '5분 배수여야 서버가 받는다');
    expect(end, isNot('23:59'));
  });
}
