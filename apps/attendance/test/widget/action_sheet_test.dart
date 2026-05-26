/// ActionSheet widget test — Phase 5 Stage D.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/providers/attendance_dashboard_provider.dart';
import 'package:attendance/widgets/action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

IdentifyResponse _user({
  String? status = 'working',
  TodayStaffBreak? currentBreak,
}) =>
    IdentifyResponse(
      userId: 'u1',
      userName: 'Marcus Lee',
      todayStatus: status,
      currentBreak: currentBreak,
    );


/// ActionSheet 는 태블릿 viewport 가정 (5 액션 wrap + 헤더 + break info).
/// default 800x600 으로는 overflow — 1200x1000 으로 늘림.
Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

bool _isTileEnabled(WidgetTester tester, String label) {
  // _ActionTile 의 InkWell onTap 이 null 이 아닌지로 판단.
  final tile = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
  final inkwell = tester.widget<InkWell>(tile);
  return inkwell.onTap != null;
}

void main() {
  testWidgets('헤더 + 이름 + 5개 액션 모두 렌더', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'working'),
      onPick: (_) {},
      onCancel: () {},
    )));
    expect(find.text('CHOOSE ACTION'), findsOneWidget);
    expect(find.text('Marcus Lee'), findsOneWidget);
    for (final l in ['Clock In', 'Clock Out', '10-min Break', 'Meal Break', 'End Break']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
  });

  testWidgets('working — Clock Out / 10-min / Meal 활성, Clock In / End 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'working'),
      onPick: (_) {},
      onCancel: () {},
    )));
    expect(_isTileEnabled(tester, 'Clock Out'), true);
    expect(_isTileEnabled(tester, '10-min Break'), true);
    expect(_isTileEnabled(tester, 'Meal Break'), true);
    expect(_isTileEnabled(tester, 'Clock In'), false);
    expect(_isTileEnabled(tester, 'End Break'), false);
  });

  testWidgets('upcoming — Clock In 만 활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'upcoming'),
      onPick: (_) {},
      onCancel: () {},
    )));
    expect(_isTileEnabled(tester, 'Clock In'), true);
    for (final l in ['Clock Out', '10-min Break', 'Meal Break', 'End Break']) {
      expect(_isTileEnabled(tester, l), false, reason: l);
    }
  });

  testWidgets('on_break under 30m (meal) — End Break disabled, Clock Out 활성', (tester) async {
    await _useTabletSurface(tester);
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 18)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'on_break', currentBreak: br),
      onPick: (_) {},
      onCancel: () {},
      now: now,
    )));
    expect(_isTileEnabled(tester, 'Clock Out'), true);
    expect(_isTileEnabled(tester, 'End Break'), false);
    // hint 메시지 ("Wait 12m more") 표시
    expect(find.textContaining('Wait 12m more'), findsOneWidget);
  });

  testWidgets('on_break within (32m meal) — End Break 활성', (tester) async {
    await _useTabletSurface(tester);
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 32)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'on_break', currentBreak: br),
      onPick: (_) {},
      onCancel: () {},
      now: now,
    )));
    expect(_isTileEnabled(tester, 'End Break'), true);
    expect(_isTileEnabled(tester, 'Clock Out'), true);
  });

  testWidgets('clocked_out — 전부 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'clocked_out'),
      onPick: (_) {},
      onCancel: () {},
    )));
    for (final l in ['Clock In', 'Clock Out', '10-min Break', 'Meal Break', 'End Break']) {
      expect(_isTileEnabled(tester, l), false, reason: l);
    }
  });

  testWidgets('todayStatus null — 전부 비활성', (tester) async {
    await _useTabletSurface(tester);
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: null),
      onPick: (_) {},
      onCancel: () {},
    )));
    for (final l in ['Clock In', 'Clock Out']) {
      expect(_isTileEnabled(tester, l), false, reason: l);
    }
  });

  testWidgets('활성 액션 탭 → onPick 호출', (tester) async {
    await _useTabletSurface(tester);
    AttendanceAction? picked;
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'working'),
      onPick: (a) => picked = a,
      onCancel: () {},
    )));
    await tester.tap(find.text('Clock Out'));
    await tester.pump();
    expect(picked, AttendanceAction.clockOut);
  });

  testWidgets('X close → onCancel 호출', (tester) async {
    await _useTabletSurface(tester);
    var canceled = 0;
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'working'),
      onPick: (_) {},
      onCancel: () => canceled++,
    )));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(canceled, 1);
  });

  testWidgets('on_break 일 때 상단 break info 박스 노출 (라벨 + Nm elapsed)', (tester) async {
    await _useTabletSurface(tester);
    final now = DateTime(2026, 5, 22, 12, 0);
    final br = TodayStaffBreak(
      startedAt: now.subtract(const Duration(minutes: 18)),
      breakType: 'unpaid_meal',
    );
    await tester.pumpWidget(wrapForTest(ActionSheet(
      user: _user(status: 'on_break', currentBreak: br),
      onPick: (_) {},
      onCancel: () {},
      now: now,
    )));
    expect(find.text('MEAL BREAK (UNPAID)'), findsOneWidget);
    expect(find.text('18m elapsed'), findsOneWidget);
  });
}
