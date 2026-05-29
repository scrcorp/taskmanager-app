/// ProfilePinRow widget tests (단순화 후).
///
/// 마스킹/Show-Hide/Regenerate 제거됨. Edit (연필 아이콘) 만.
///
/// 다루는 분기:
///  - 초기 load → PIN 평문 표시 + Edit 아이콘
///  - PIN 없을 때 → em dash + Edit 숨김
///  - Edit → 4자리 입력 → Save → updatePin 호출 + PIN 갱신
///  - Edit → 3자리 → Save 무반응
///  - updatePin 실패 (pin_not_available) → "Not available" 모달
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/services/clockin_pin_service.dart';
import 'package:app/widgets/profile_pin_row.dart';

class _FakeService extends ClockinPinService {
  _FakeService() : super(Dio());

  String? currentPin;
  bool throwNotAvailable = false;
  int updateCount = 0;
  String? lastUpdatePin;

  @override
  Future<Map<String, dynamic>> getPin() async {
    return {'user_id': 'u1', 'clockin_pin': currentPin};
  }

  @override
  Future<Map<String, dynamic>> updatePin(String pin) async {
    updateCount++;
    lastUpdatePin = pin;
    if (throwNotAvailable) throw Exception('pin_not_available');
    currentPin = pin;
    return {'user_id': 'u1', 'clockin_pin': pin};
  }
}

Widget _wrap(Widget child, _FakeService service) {
  return ProviderScope(
    overrides: [
      clockinPinServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('초기 load → PIN 평문 표시 + Edit 아이콘', (tester) async {
    final fake = _FakeService()..currentPin = '123456';
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    expect(find.text('Clock-in PIN'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget); // 평문 그대로
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('PIN 없을 때 — em dash + Edit 아이콘 숨김', (tester) async {
    final fake = _FakeService()..currentPin = null;
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('Edit → 4자리 입력 → Save → updatePin + PIN 갱신', (tester) async {
    final fake = _FakeService()..currentPin = '123456';
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '4321');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fake.updateCount, 1);
    expect(fake.lastUpdatePin, '4321');
    expect(find.text('4321'), findsOneWidget);
  });

  testWidgets('Edit → 3자리 → Save 무반응 (regex 실패)', (tester) async {
    final fake = _FakeService()..currentPin = '123456';
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(fake.updateCount, 0);
  });

  testWidgets('updatePin 실패 (pin_not_available) → Not available 모달', (tester) async {
    final fake = _FakeService()
      ..currentPin = '123456'
      ..throwNotAvailable = true;
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4321');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fake.updateCount, 1);
    expect(find.text('Not available'), findsWidgets);
  });

  testWidgets('Edit → Cancel → 편집 종료, PIN 그대로', (tester) async {
    final fake = _FakeService()..currentPin = '123456';
    await tester.pumpWidget(_wrap(const ProfilePinRow(), fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '99');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(fake.updateCount, 0);
    expect(find.text('123456'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
