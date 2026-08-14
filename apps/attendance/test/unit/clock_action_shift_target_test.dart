/// clock-out / break / manage 액션이 **어느 shift 를 대상으로 하는지** 서버에
/// 지목하는지 검증한다 (계약 §3.9).
///
/// 겹침(D15)을 허용한 뒤로 한 사람에게 열린 row 가 둘일 수 있다. 그때 앱이
/// `schedule_id` 를 안 보내면 서버 `_active_row()` 는 status 순서로 훑어 아무
/// 쪽이나 닫는다 — **화면이 가리킨 shift 와 실제로 닫힌 shift 가 갈린다.**
/// 서버가 받아들이게 만들어 놓고 클라가 안 보내면 계약이 무효이므로,
/// "요청 body 에 실렸다" 를 전선에서 확인한다.

import 'package:attendance/providers/attendance_device_provider.dart';
import 'package:attendance/services/attendance_device_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청을 실제로 보내지 않고 body 만 붙잡는다. index 0 에 꽂아 device token /
/// 버전 헤더 인터셉터(플랫폼 채널 의존)보다 먼저 끝낸다.
List<RequestOptions> _capture(AttendanceDeviceService service) {
  final captured = <RequestOptions>[];
  service.debugDio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      captured.add(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{},
      ));
    }),
  );
  return captured;
}

Map<String, dynamic> _body(RequestOptions options) =>
    Map<String, dynamic>.from(options.data as Map);

/// performClockAction 이 service 로 무엇을 넘기는지 붙잡는 대역.
class _SpyService extends AttendanceDeviceService {
  String? clockOutScheduleId;
  String? breakStartScheduleId;
  String? breakEndScheduleId;

  @override
  Future<Map<String, dynamic>> clockOut({
    required String userId,
    required String pin,
    String? reason,
    String? scheduleId,
  }) async {
    clockOutScheduleId = scheduleId;
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> breakStart({
    required String userId,
    required String pin,
    required String breakType,
    String? scheduleId,
  }) async {
    breakStartScheduleId = scheduleId;
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> breakEnd({
    required String userId,
    required String pin,
    String? reason,
    String? scheduleId,
  }) async {
    breakEndScheduleId = scheduleId;
    return <String, dynamic>{};
  }
}

void main() {
  group('기기 경로 — 요청 body 에 schedule_id 가 실린다', () {
    test('clock-out', () async {
      final service = AttendanceDeviceService();
      final captured = _capture(service);
      await service.clockOut(userId: 'u1', pin: '123456', scheduleId: 's-late');
      expect(_body(captured.single)['schedule_id'], 's-late');
    });

    test('break-start / break-end', () async {
      final service = AttendanceDeviceService();
      final captured = _capture(service);
      await service.breakStart(
        userId: 'u1', pin: '123456', breakType: 'paid_10min', scheduleId: 's1',
      );
      await service.breakEnd(userId: 'u1', pin: '123456', scheduleId: 's1');
      expect(_body(captured[0])['schedule_id'], 's1');
      expect(_body(captured[1])['schedule_id'], 's1');
    });

    test('schedule_id 가 없으면 키 자체를 안 보낸다 (서버 fallback 유지)', () async {
      final service = AttendanceDeviceService();
      final captured = _capture(service);
      await service.clockOut(userId: 'u1', pin: '123456');
      expect(_body(captured.single).containsKey('schedule_id'), isFalse);
    });

    test('매니저 모드도 고른 행을 지목한다', () async {
      final service = AttendanceDeviceService();
      final captured = _capture(service);
      await service.manageClockAction(
        userId: 'u1', action: 'break_end', scheduleId: 's2',
      );
      expect(_body(captured.single)['schedule_id'], 's2');
    });
  });

  group('provider — performClockAction 이 scheduleId 를 떨어뜨리지 않는다', () {
    test('clock-out / break-start / break-end 전부 전달', () async {
      final spy = _SpyService();
      final notifier = AttendanceDeviceNotifier(spy);

      await notifier.performClockAction(
        action: 'clock-out', userId: 'u1', pin: '123456', scheduleId: 's9',
      );
      await notifier.performClockAction(
        action: 'break-start', userId: 'u1', pin: '123456',
        breakType: 'paid_10min', scheduleId: 's9',
      );
      await notifier.performClockAction(
        action: 'break-end', userId: 'u1', pin: '123456', scheduleId: 's9',
      );

      expect(spy.clockOutScheduleId, 's9');
      expect(spy.breakStartScheduleId, 's9');
      expect(spy.breakEndScheduleId, 's9');
    });
  });
}
