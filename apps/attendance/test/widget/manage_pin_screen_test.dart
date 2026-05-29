/// AttendanceManagePinScreen widget test — Issue 6 (PinNumpad 재사용).
///
/// 검증:
///   - PinNumpad 위젯이 렌더되는지 (자체 numpad 가 아닌)
///   - MANAGE MODE 배지 + heading + Cancel & Return 보임
///   - PinNumpad 의 4~6 가변 입력 → Verify Identity 버튼 활성/비활성
///
/// verify 흐름의 provider/navigation 은 별 e2e 영역 — 본 test 범위 밖.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/l10n/app_localizations.dart';
import 'package:attendance/screens/attendance/attendance_manage_pin_screen.dart';
import 'package:attendance/widgets/pin_numpad.dart';

import '_test_helpers.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('PinNumpad widget 으로 교체됨 (자체 numpad 아님)', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(const AttendanceManagePinScreen()));
    await tester.pump();

    // PinNumpad 위젯이 정확히 1개 렌더 — 메인과 동일 위젯 재사용 증거
    expect(find.byType(PinNumpad), findsOneWidget);
  });

  testWidgets('MANAGE MODE 배지 + Cancel & Return 표시', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(const AttendanceManagePinScreen()));
    await tester.pump();

    expect(find.text('MANAGE MODE'), findsOneWidget);
    expect(find.text('Cancel & Return'), findsOneWidget);
  });

  testWidgets('PinNumpad — 3자리 입력 시 Verify Identity 비활성, 4자리 활성', (tester) async {
    await useTabletSurface(tester);
    await tester.pumpWidget(_wrap(const AttendanceManagePinScreen()));
    await tester.pump();

    // 3자리만 입력 — minLength=4 미만이라 Verify 비활성
    for (final d in const ['1', '2', '3']) {
      await tester.tap(find.text(d));
    }
    await tester.pump();
    final submit3 = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verify Identity'),
    );
    expect(submit3.onPressed, isNull, reason: '3자리 → 비활성');

    // 1자리 더 → 4자리 → 활성
    await tester.tap(find.text('4'));
    await tester.pump();
    final submit4 = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verify Identity'),
    );
    expect(submit4.onPressed, isNotNull, reason: '4자리 → 활성');
  });
}
