/// TipEntryDialog widget test — Phase 5 Stage F.

import 'package:attendance/models/tip_models.dart';
import 'package:attendance/widgets/tip_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';


Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

List<TipReceiver> _receivers() => const [
      TipReceiver(userId: 'u1', userName: 'Sarah Kim', role: 'Barista', workedHours: 6.5),
      TipReceiver(userId: 'u2', userName: 'Jin Park', role: 'Kitchen', workedHours: 8),
      TipReceiver(userId: 'u3', userName: 'Mia Chen', role: 'Server', workedHours: 4),
    ];

TipEntryDialog _build({
  ValueChanged<TipPayload>? onSubmit,
  VoidCallback? onSkip,
  List<TipReceiver>? receivers,
}) =>
    TipEntryDialog(
      userName: 'Marcus Lee',
      receivers: receivers ?? _receivers(),
      onSubmit: onSubmit ?? (_) {},
      onSkip: onSkip ?? () {},
    );

bool _isSubmitEnabled(WidgetTester tester) {
  final btn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit Tips'),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('헤더 + 이름 + 두 입력 필드 + receivers 렌더, 초기 Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    expect(find.text('TIP ENTRY'), findsOneWidget);
    expect(find.text("Marcus Lee's tips today"), findsOneWidget);
    expect(find.text('Card Tips'), findsOneWidget);
    expect(find.text('Cash Tips Kept'), findsOneWidget);
    expect(find.text('Sarah Kim'), findsOneWidget);
    expect(find.text('Jin Park'), findsOneWidget);
    expect(find.text('Mia Chen'), findsOneWidget);
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('Skip 탭 → onSkip 호출', (tester) async {
    await _useTabletSurface(tester);
    var skipped = 0;
    await tester.pumpWidget(wrapForTest(_build(onSkip: () => skipped++)));
    await tester.tap(find.text('Skip — enter later'));
    await tester.pump();
    expect(skipped, 1);
  });

  testWidgets('card/cash 둘 다 입력 + 분배 없음 → Submit 활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(1), '10');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);
  });

  testWidgets('한쪽만 입력 → Submit 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);
  });

  testWidgets('receiver 체크 → amount input 등장', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('Split evenly → 선택된 receiver들에 균등 분배', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(1), '10');
    await tester.pump();
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    await tester.tap(find.text('Jin Park'));
    await tester.pump();
    await tester.tap(find.text('Split evenly'));
    await tester.pump();
    // 60 / 2 = 30.00
    expect(find.text('30.00'), findsNWidgets(2));
  });

  testWidgets('분배합이 card tips 초과 → Submit 비활성 + Over 라벨', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20');
    await tester.enterText(fields.at(1), '5');
    await tester.pump();
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    final amountField = find.byType(TextField).last;
    await tester.enterText(amountField, '50');
    await tester.pump();
    expect(_isSubmitEnabled(tester), false);
    expect(find.textContaining('Over by'), findsOneWidget);
  });

  testWidgets('Submit → onSubmit payload 정확', (tester) async {
    await _useTabletSurface(tester);
    TipPayload? got;
    await tester.pumpWidget(wrapForTest(_build(onSubmit: (p) => got = p)));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '40');
    await tester.enterText(fields.at(1), '12');
    await tester.pump();
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    final amountField = find.byType(TextField).last;
    await tester.enterText(amountField, '25');
    await tester.pump();
    await tester.tap(find.text('Submit Tips'));
    await tester.pump();
    expect(got, isNotNull);
    expect(got!.cardTips, 40);
    expect(got!.cashTipsKept, 12);
    expect(got!.distributions.length, 1);
    expect(got!.distributions.first.receiverId, 'u1');
    expect(got!.distributions.first.amount, 25);
  });

  testWidgets('receivers 비어있음 → "No teammates" 안내 + Submit 가능 (card/cash 채우면)', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build(receivers: const [])));
    expect(find.textContaining('No teammates'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '15');
    await tester.enterText(fields.at(1), '5');
    await tester.pump();
    expect(_isSubmitEnabled(tester), true);
  });

  testWidgets('receiver 해제 → amount field 사라짐', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(_build()));
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.tap(find.text('Sarah Kim'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
