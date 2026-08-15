/// EarlyClockInDialog widget test.
///
/// 핵심은 "매니저 없이도 사유를 넣어 실제로 출근을 찍을 수 있는가" — 이 화면이
/// 없으면 일찍 와달라고 불린 직원이 출근 기록을 못 남긴다(원래 문제).
///
/// 얼마나 이른지 표시도 함께 본다. 서버가 시간 상한을 두지 않으므로 오조작
/// (다음날 shift 선택 등)을 사용자가 알아채는 장치가 이 문구뿐이다.
///
/// 2026-08-13(D8~D10): "Asked to come in early" 는 **누가 불렀는지**까지 받는다.
/// "Someone else" 가 상시 노출되는지가 이 화면의 회귀 포인트다 — 목록만 두면
/// 명단 밖 사람(본사·타 매장 매니저)이 부른 경우에 출근이 막힌다.

import 'package:attendance/models/store_manager_option.dart';
import 'package:attendance/widgets/early_clock_in_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

const _managers = [
  StoreManagerOption(
    userId: 'u-gm',
    fullName: 'John Kim',
    roleName: 'General Manager',
    rolePriority: 20,
  ),
  StoreManagerOption(
    userId: 'u-sv',
    fullName: 'Ana Ruiz',
    roleName: 'Supervisor',
    rolePriority: 30,
  ),
];

EarlyClockInDialog _build({
  void Function(String reason, String? requestedBy)? onSubmit,
  VoidCallback? onCancel,
  int minutesEarly = 125,
  String? errorText,
  List<StoreManagerOption> managers = const [],
  bool managersLoading = false,
  bool managersFailed = false,
}) =>
    EarlyClockInDialog(
      userName: 'Marcus Lee',
      minutesEarly: minutesEarly,
      managers: managers,
      managersLoading: managersLoading,
      managersFailed: managersFailed,
      onSubmit: onSubmit ?? (_, __) {},
      onCancel: onCancel ?? () {},
      errorText: errorText,
    );

bool _isSubmitEnabled(WidgetTester tester) {
  final btn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit & Clock In'),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('헤더 + 이른 정도 + 프리셋 렌더, 초기 Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));

    expect(find.text('EARLY CLOCK-IN'), findsOneWidget);
    expect(find.text('2h 5m before your shift starts'), findsOneWidget);
    expect(find.text('Asked to come in early'), findsOneWidget);
    expect(find.text('Covering for someone'), findsOneWidget);
    expect(find.text('Store needs help now'), findsOneWidget);
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('요청자가 없는 프리셋 → 바로 Submit 활성 + 라벨만 전달', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    String? requestedBy = 'sentinel';
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r, id) {
        submitted = r;
        requestedBy = id;
      })),
    );

    await tester.tap(find.text('Covering for someone'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Covering for someone');
    // D10 — 다른 프리셋엔 대상자를 붙이지 않는다.
    expect(requestedBy, isNull);
  });

  testWidgets('"불려서 왔다" → 목록에서 고르면 이름이 붙고 user_id 도 함께 간다', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    String? requestedBy;
    await tester.pumpWidget(
      wrapForTest(_build(
        managers: _managers,
        onSubmit: (r, id) {
          submitted = r;
          requestedBy = id;
        },
      )),
    );

    await tester.tap(find.text('Asked to come in early'));
    await tester.pump();
    // 대상자를 안 고르면 제출 못 한다.
    expect(_isSubmitEnabled(tester), false);
    expect(find.text('Who asked you to come in early?'), findsOneWidget);
    expect(find.text('John Kim'), findsOneWidget);
    // 동명이인 구분을 위해 role 을 함께 보여준다.
    expect(find.text('General Manager'), findsOneWidget);

    await tester.tap(find.text('John Kim'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Asked to come in early (John Kim)');
    expect(requestedBy, 'u-gm');
  });

  testWidgets('"Someone else" 는 목록이 있어도 항상 노출된다 (fallback 이 아니다)',
      (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    String? requestedBy = 'sentinel';
    await tester.pumpWidget(
      wrapForTest(_build(
        managers: _managers,
        onSubmit: (r, id) {
          submitted = r;
          requestedBy = id;
        },
      )),
    );

    await tester.tap(find.text('Asked to come in early'));
    await tester.pump();
    expect(find.text('Someone else'), findsOneWidget);

    await tester.tap(find.text('Someone else'));
    await tester.pump();
    // 이름을 적기 전엔 제출 불가.
    expect(_isSubmitEnabled(tester), false);

    await tester.enterText(find.byType(TextField), 'Sam from HQ');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Asked to come in early (Sam from HQ)');
    // 명단 밖 사람이라 id 가 없다 (D9).
    expect(requestedBy, isNull);
  });

  testWidgets('목록 조회 실패 → 안내 + "Someone else" 로 계속 진행할 수 있다',
      (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(
      wrapForTest(_build(managersFailed: true)),
    );

    await tester.tap(find.text('Asked to come in early'));
    await tester.pump();
    expect(
      find.text('Could not load the manager list. Enter the name below.'),
      findsOneWidget,
    );
    expect(find.text('Someone else'), findsOneWidget);
  });

  testWidgets('사유를 바꾸면 요청자 선택이 따라 붙지 않는다', (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    String? requestedBy = 'sentinel';
    await tester.pumpWidget(
      wrapForTest(_build(
        managers: _managers,
        onSubmit: (r, id) {
          submitted = r;
          requestedBy = id;
        },
      )),
    );

    await tester.tap(find.text('Asked to come in early'));
    await tester.pump();
    await tester.tap(find.text('John Kim'));
    await tester.pump();

    await tester.tap(find.text('Store needs help now'));
    await tester.pump();
    expect(find.text('Who asked you to come in early?'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Store needs help now');
    expect(requestedBy, isNull);
  });

  testWidgets('Other 선택 → 입력 전 Submit 비활성, 입력 후 활성 + 그 문장 전달',
      (tester) async {
    await _useTabletSurface(tester);
    String? submitted;
    await tester.pumpWidget(
      wrapForTest(_build(onSubmit: (r, _) => submitted = r)),
    );

    await tester.tap(find.text('Other (please specify)'));
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);

    await tester.enterText(find.byType(TextField), 'Bus arrived early');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & Clock In'));
    await tester.pump();
    expect(submitted, 'Bus arrived early');
  });

  testWidgets('취소 → onCancel 호출 (출근은 성립하지 않는다)', (tester) async {
    await _useTabletSurface(tester);
    var cancelled = false;
    await tester.pumpWidget(
      wrapForTest(_build(onCancel: () => cancelled = true)),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    expect(cancelled, true);
  });

  testWidgets('서버 거부 메시지는 화면 안에서 보여준다 (raw 에러 대신)', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(
      wrapForTest(_build(errorText: 'Selected shift is not available')),
    );

    expect(find.text('Selected shift is not available'), findsOneWidget);
  });

  testWidgets('60분 미만이면 분만 표시', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build(minutesEarly: 45)));

    expect(find.text('45m before your shift starts'), findsOneWidget);
  });
}
