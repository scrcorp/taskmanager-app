/// AttendanceManageStaffPinsScreen widget test.
///
/// 이 화면의 핵심 계약은 **평문 PIN 이 기본으로 화면에 없다**는 것. 키오스크는
/// 매장 공용 화면이라, 목록이 평문으로 떠 있으면 매니저가 자리를 비운 순간
/// 전 직원 PIN 이 노출된다. 그래서 다음을 고정한다.
///   - 최초 렌더는 마스킹만
///   - Reveal 을 눌러야 서버에서 평문을 가져오고(=감사 로그가 남고) 표시
///   - update 권한이 없으면 변경 메뉴 자체가 없음
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/l10n/app_localizations.dart';
import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/screens/attendance/attendance_manage_staff_pins_screen.dart';
import 'package:attendance/services/attendance_device_service.dart';

import '_test_helpers.dart';

/// 네트워크 없이 동작하는 대역. reveal 호출 횟수를 세서
/// "목록 렌더만으로 평문을 당겨오지 않는다" 를 검증한다.
class _FakeService extends AttendanceDeviceService {
  int revealCalls = 0;
  String? lastRevealedUserId;
  int regenerateCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> manageListStaffPins({
    String? query,
  }) async {
    final rows = [
      {
        'user_id': 'u-1',
        'full_name': 'Alice Kim',
        'employee_no': 'EMP001',
        'role_name': 'Staff',
        'has_pin': true,
        'works_today': true,
      },
      {
        'user_id': 'u-2',
        'full_name': 'Bob Lee',
        'employee_no': 'EMP002',
        'role_name': 'Staff',
        'has_pin': false,
        'works_today': false,
      },
    ];
    if (query == null || query.isEmpty) return rows;
    return rows
        .where(
          (r) => (r['full_name'] as String).toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Future<String?> manageRevealStaffPin(String userId) async {
    revealCalls += 1;
    lastRevealedUserId = userId;
    return '482913';
  }

  @override
  Future<String?> manageRegenerateStaffPin(String userId) async {
    regenerateCalls += 1;
    return '135790';
  }
}

/// PIN 저장이 409 로 거절되는 대역 — detail 형태(dict/문자열)별 문구 매핑 검증용.
class _Conflict409Service extends _FakeService {
  final Object detail;
  _Conflict409Service(this.detail);

  @override
  Future<String?> manageUpdateStaffPin({
    required String userId,
    required String pin,
  }) async {
    final req = RequestOptions(path: '/attendance/manage/staff-pins/$userId');
    throw DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: req,
        statusCode: 409,
        data: {'detail': detail},
      ),
    );
  }
}

Widget _wrap(_FakeService service, {bool canUpdate = true}) {
  return ProviderScope(
    overrides: [
      attendanceDeviceServiceProvider.overrideWithValue(service),
      attendanceManageSessionProvider.overrideWith(
        (ref) => _StubSessionNotifier(
          service,
          ManageSessionState(
            active: true,
            canReadPins: true,
            canUpdatePins: canUpdate,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const AttendanceManageStaffPinsScreen(),
    ),
  );
}

class _StubSessionNotifier extends AttendanceManageSessionNotifier {
  _StubSessionNotifier(super.service, ManageSessionState initial) {
    state = initial;
  }
}

void main() {
  testWidgets('목록은 마스킹만 보여준다 — 평문 PIN 을 미리 당겨오지 않음', (tester) async {
    await useTabletSurface(tester);
    final service = _FakeService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Alice Kim'), findsOneWidget);
    expect(find.text('••••••'), findsOneWidget); // PIN 있는 사람만
    expect(find.text('482913'), findsNothing);
    expect(
      service.revealCalls,
      0,
      reason: '목록 렌더만으로 reveal API 를 호출하면 감사 로그가 의미를 잃는다',
    );
  });

  testWidgets('PIN 이 없는 직원은 No PIN 으로 표시', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    expect(find.text('Bob Lee'), findsOneWidget);
    expect(find.text('No PIN'), findsOneWidget);
  });

  testWidgets('Reveal 을 눌러야 평문이 뜨고 그때 서버를 호출한다', (tester) async {
    await useTabletSurface(tester);
    final service = _FakeService();
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.visibility_rounded).first);
    await tester.pump();
    await tester.pump();

    expect(service.revealCalls, 1);
    expect(service.lastRevealedUserId, 'u-1');
    expect(find.text('482913'), findsOneWidget);
  });

  testWidgets('평문은 5초 뒤 자동으로 다시 마스킹된다', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.visibility_rounded).first);
    await tester.pump();
    await tester.pump();
    expect(find.text('482913'), findsOneWidget);

    // 카운트다운 소진
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('482913'), findsNothing);
    expect(find.text('••••••'), findsOneWidget);
  });

  testWidgets('열린 행을 다시 누르면 즉시 마스킹', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.visibility_rounded).first);
    await tester.pump();
    await tester.pump();
    expect(find.text('482913'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_rounded).first);
    await tester.pump();
    expect(find.text('482913'), findsNothing);
  });

  testWidgets('update 권한이 없으면 변경 메뉴가 렌더되지 않는다', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService(), canUpdate: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    // 조회는 여전히 가능해야 한다
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
  });

  testWidgets('update 권한이 있으면 변경 메뉴가 보인다', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(2));
  });

  testWidgets('검색어로 목록이 좁혀진다', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Alice Kim'), findsOneWidget);
    expect(find.text('Bob Lee'), findsNothing);
  });

  // ── 에뮬레이터 검증에서 잡힌 회귀 ──────────────────────────

  testWidgets('저장 다이얼로그가 화면 안에 들어간다 (overflow 없음)', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Save 버튼이 실제로 렌더되어야 한다 — 잘리면 PIN 을 아예 못 바꾼다.
    expect(find.text('Save PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 버튼 문구가 Verify Identity 가 아니다', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_FakeService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // 남의 PIN 을 지정하는 화면에서 "본인 확인" 문구가 뜨면 맥락이 어긋난다.
    expect(find.text('Verify Identity'), findsNothing);
    expect(find.textContaining('tap Save PIN'), findsOneWidget);
  });

  testWidgets('화면 터치가 상위 세션 타이머에 활동으로 전달된다', (tester) async {
    await useTabletSurface(tester);
    final service = _FakeService();
    var activityCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceDeviceServiceProvider.overrideWithValue(service),
          attendanceManageSessionProvider.overrideWith(
            (ref) => _StubSessionNotifier(
              service,
              const ManageSessionState(
                active: true,
                canReadPins: true,
                canUpdatePins: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: AttendanceManageStaffPinsScreen(
            onActivity: () => activityCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice Kim'));
    await tester.pump();

    // 이게 끊기면 PIN 을 찾는 도중 manage 세션이 만료된다.
    expect(activityCount, greaterThan(0));
  });

  // ── 409 detail dict → 사유별 문구 매핑 (2-C) ────────────────

  /// Edit 다이얼로그를 열어 4자리를 입력하고 저장까지 진행.
  Future<void> submitPinChange(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('1'));
      await tester.pump();
    }
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
  }

  /// SnackBar 잔여 타이머 정리 — 없으면 테스트 종료 시 pending Timer 로 실패.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('409 other_store=true → 다른 매장 사용중 문구', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(
      _wrap(
        _Conflict409Service(
          {'code': 'pin_conflict', 'reason': 'exact', 'other_store': true},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await submitPinChange(tester);

    expect(
      find.text(
        'This PIN is already used by an employee at another store. '
        'Pick a different number.',
      ),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });

  testWidgets('409 exact + 같은 매장 → 기존 conflict 문구', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(
      _wrap(
        _Conflict409Service(
          {'code': 'pin_conflict', 'reason': 'exact', 'other_store': false},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await submitPinChange(tester);

    expect(
      find.text(
        "This PIN conflicts with another employee's PIN. "
        'Please enter a different number.',
      ),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });

  testWidgets('409 detail 이 문자열(구버전 서버) → 기존 conflict 문구 fallback',
      (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(_Conflict409Service('Not available')));
    await tester.pumpAndSettle();

    await submitPinChange(tester);

    // raw detail("Not available") 이 그대로 노출되면 안 된다.
    expect(find.text('Not available'), findsNothing);
    expect(
      find.text(
        "This PIN conflicts with another employee's PIN. "
        'Please enter a different number.',
      ),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });
}
