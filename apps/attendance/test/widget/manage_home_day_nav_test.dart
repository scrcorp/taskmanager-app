/// 매니저 홈의 영업일 이동(F5).
///
/// 고정하려는 계약:
///   1. 기본은 오늘 — 서버에 `operating_day` 를 **안 보낸다**(영업일 경계를 서버가 판단).
///   2. ‹ › 로 이동하면 그 날짜가 파라미터로 나간다.
///   3. 오늘이 아닌 날은 화면에 그 사실이 드러난다 (오늘로 착각하면 엉뚱한 날을 고친다).
///   4. Today 로 돌아오면 다시 파라미터 없는 조회가 된다.

import 'package:attendance/l10n/app_localizations.dart';
import 'package:attendance/providers/attendance_device_provider.dart';
import 'package:attendance/screens/attendance/attendance_manage_home_screen.dart';
import 'package:attendance/services/attendance_device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

class _FakeService extends AttendanceDeviceService {
  /// 조회마다 넘어온 operating_day (null = 안 보냄 = 오늘).
  final List<String?> requestedDays = [];

  @override
  Future<List<Map<String, dynamic>>> manageListSchedules({
    String? operatingDay,
  }) async {
    requestedDays.add(operatingDay);
    return const [];
  }
}

/// 기기 상태를 ready + work_date 로 고정. work_date 는 서버가 store tz + day_start
/// 로 계산해 준 "오늘 영업일" 이다.
class _FakeDeviceNotifier extends AttendanceDeviceNotifier {
  _FakeDeviceNotifier(super.service, DeviceInfo device) {
    state = AttendanceDeviceState(
      status: AttendanceDeviceStatus.ready,
      device: device,
    );
  }
}

Future<void> _pumpHome(WidgetTester tester, _FakeService service) async {
  await useTabletSurface(tester);
  const device = DeviceInfo(
    deviceId: 'd-1',
    deviceName: 'Kiosk',
    organizationId: 'o-1',
    storeId: 's-1',
    storeName: 'Store',
    workDate: '2026-08-10', // Mon
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attendanceDeviceServiceProvider.overrideWithValue(service),
        attendanceDeviceProvider
            .overrideWith((ref) => _FakeDeviceNotifier(service, device)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: AttendanceManageHomeScreen(),
      ),
    ),
  );
  // 1초 틱 타이머가 계속 프레임을 만들어 pumpAndSettle 이 끝나지 않는다 — 고정 횟수만 pump.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// 화면을 내려 타이머를 dispose 시킨다 (테스트 종료 시 pending timer 경고 방지).
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('기본은 오늘 — operating_day 를 보내지 않는다', (tester) async {
    final service = _FakeService();
    await _pumpHome(tester, service);

    expect(service.requestedDays, [null]);
    expect(find.text('Mon, Aug 10'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await _dispose(tester);
  });

  testWidgets('› 로 다음 영업일 — 날짜가 파라미터로 나가고 화면에 드러난다', (tester) async {
    final service = _FakeService();
    await _pumpHome(tester, service);

    await tester.tap(find.byTooltip('Next day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.requestedDays, [null, '2026-08-11']);
    expect(find.text('Tue, Aug 11'), findsOneWidget);
    // 오늘이 아니라는 사실이 문구로 남아야 한다.
    expect(find.textContaining('not viewing today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    // 빈 목록 문구도 그 날짜를 말한다.
    expect(find.text('No schedules for Tue, Aug 11'), findsOneWidget);

    await _dispose(tester);
  });

  testWidgets('‹ 두 번 → 이틀 전, Today 로 돌아오면 다시 파라미터 없음', (tester) async {
    final service = _FakeService();
    await _pumpHome(tester, service);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(service.requestedDays, [null, '2026-08-09', '2026-08-08']);
    expect(find.text('2 days ago'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.requestedDays.last, isNull);
    expect(find.textContaining('not viewing today'), findsNothing);

    await _dispose(tester);
  });
}
