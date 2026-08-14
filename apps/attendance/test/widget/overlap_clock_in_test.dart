/// 겹침 clock-in 표시 경로 widget test (페이즈 ⑤).
///
/// 겹침은 "급여가 두 번 나가는" 상태다. 그래서 표시가 세 자리에 있어야 한다:
///  1. 찍기 직전 — 확인 다이얼로그 (여기서 멈출 수 있다)
///  2. 찍은 직후 — 성공 화면 안내 (자동으로 사라지면 안 된다)
///  3. 해소될 때까지 — PIN 식별 화면 배너 (한 번만 보여주면 교대 끝까지 아무도 모른다)

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/widgets/identity_confirm_dialog.dart';
import 'package:attendance/widgets/overlap_confirm_dialog.dart';
import 'package:attendance/widgets/success_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

TodayAttendanceItem _item(String id, {bool overlapping = false}) =>
    TodayAttendanceItem(
      scheduleId: id,
      status: 'working',
      scheduledStartDisplay: '09:00',
      scheduledEndDisplay: '13:00',
      overlapping: overlapping,
    );

void main() {
  group('OverlapConfirmDialog — 찍기 직전', () {
    testWidgets('열린 shift 시간대를 알려준다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(OverlapConfirmDialog(
        openStartDisplay: '09:00',
        openEndDisplay: '13:00',
        onConfirm: () {},
        onCancel: () {},
      )));

      expect(find.text('You are still clocked in'), findsOneWidget);
      expect(find.text('Still open: 09:00 – 13:00'), findsOneWidget);
    });

    testWidgets('시간대를 모르면 일반 문구만 (줄을 지어내지 않는다)', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(OverlapConfirmDialog(
        onConfirm: () {},
        onCancel: () {},
      )));

      expect(find.textContaining('Still open'), findsNothing);
      expect(find.text('Clock in anyway'), findsOneWidget);
    });

    testWidgets('확인 / 취소 콜백', (tester) async {
      await _surface(tester);
      var confirmed = false;
      var cancelled = false;
      await tester.pumpWidget(wrapForTest(OverlapConfirmDialog(
        onConfirm: () => confirmed = true,
        onCancel: () => cancelled = true,
      )));

      await tester.tap(find.text('Clock in anyway'));
      await tester.pump();
      expect(confirmed, isTrue);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });

  group('SuccessModal — 찍은 직후', () {
    testWidgets('겹침 안내가 붙고 자동 닫힘이 꺼진다', (tester) async {
      await _surface(tester);
      var closed = false;
      await tester.pumpWidget(wrapForTest(SuccessModal(
        userName: 'Alice',
        action: AttendanceAction.clockIn,
        onClose: () => closed = true,
        noticeTitle: 'You are clocked in to two shifts.',
        noticeBody: 'Tell your manager to fix one of them.',
      )));

      expect(find.text('You are clocked in to two shifts.'), findsOneWidget);
      expect(find.text('Tell your manager to fix one of them.'), findsOneWidget);

      // 5초를 넘겨도 닫히지 않는다 — 안내가 사라지면 안 한 것과 같다.
      await tester.pump(const Duration(seconds: 8));
      expect(closed, isFalse);
    });

    testWidgets('안내가 없으면 기존대로 5초 자동 닫힘', (tester) async {
      await _surface(tester);
      var closed = false;
      await tester.pumpWidget(wrapForTest(SuccessModal(
        userName: 'Alice',
        action: AttendanceAction.clockIn,
        onClose: () => closed = true,
      )));

      await tester.pump(const Duration(seconds: 6));
      expect(closed, isTrue);
    });
  });

  group('IdentityConfirmDialog — 해소될 때까지', () {
    testWidgets('overlapping 항목이 있으면 배너가 매번 뜬다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
        user: IdentifyResponse(
          userId: 'u1',
          userName: 'Alice',
          todayStatus: 'working',
          todayAttendances: [_item('s1', overlapping: true), _item('s2')],
        ),
        onYes: () {},
        onClose: () {},
      )));

      expect(find.text('You are clocked in to two shifts.'), findsOneWidget);
      expect(find.text('Tell your manager to fix one of them.'), findsOneWidget);
    });

    testWidgets('겹침이 없으면 배너도 없다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(IdentityConfirmDialog(
        user: IdentifyResponse(
          userId: 'u1',
          userName: 'Alice',
          todayStatus: 'working',
          todayAttendances: [_item('s1')],
        ),
        onYes: () {},
        onClose: () {},
      )));

      expect(find.text('You are clocked in to two shifts.'), findsNothing);
    });
  });
}
