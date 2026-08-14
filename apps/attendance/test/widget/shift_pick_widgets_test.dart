/// shift 기본 제시 카드 + 선택 목록 widget test (페이즈 ④).
///
/// 이 화면들이 지켜야 하는 두 가지:
///  1. 정상 출근자는 탭이 늘지 않는다 — 목록을 먼저 띄우지 않고 카드 하나만 보여준다.
///  2. 판정 프리뷰가 **눈에 띄어야** 한다. 서버 fallback 이 "시간순 첫 미출근" 으로
///     바뀌면서 저녁 조만 일하는 날에도 오전 no_show 가 먼저 제시된다 —
///     "7h 12m late" 를 사용자가 못 보면 이 트랙이 원점으로 돌아간다(계약 §1.8).

import 'package:attendance/models/identify_response.dart';
import 'package:attendance/utils/shift_pick_logic.dart';
import 'package:attendance/widgets/shift_picker_dialog.dart';
import 'package:attendance/widgets/shift_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

TodayAttendanceItem _item(
  String id, {
  String status = 'upcoming',
  String? start = '09:00',
  String? end = '13:00',
  bool eligible = true,
  String? ineligibleReason,
  ClockInPreview? preview,
  String? operatingDay,
}) =>
    TodayAttendanceItem(
      scheduleId: id,
      status: status,
      scheduledStartDisplay: start,
      scheduledEndDisplay: end,
      clockInEligible: eligible,
      ineligibleReason: ineligibleReason,
      clockInPreview: preview,
      operatingDay: operatingDay,
    );

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('ShiftSummaryCard — 기본 제시 (D14)', () {
    testWidgets('시간대 + 프리뷰를 보여준다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item(
          's1',
          status: 'no_show',
          preview: const ClockInPreview(kind: 'late', minutesLate: 192),
        ),
      )));

      expect(find.text('09:00 – 13:00'), findsOneWidget);
      expect(find.text('3h 12m late'), findsOneWidget);
    });

    testWidgets('프리뷰는 본문 크기다 (작은 회색 캡션 금지 — §1.8)', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item(
          's1',
          preview: const ClockInPreview(kind: 'late', minutesLate: 432),
        ),
      )));

      final style = tester.widget<Text>(find.text('7h 12m late')).style!;
      expect(style.fontSize, greaterThanOrEqualTo(18));
      expect(style.fontWeight, FontWeight.w800);
    });

    testWidgets('early 면 "Reason required" 배지로 400 왕복을 예고한다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item(
          's1',
          preview: const ClockInPreview(
            kind: 'early',
            minutesEarly: 18,
            reasonRequired: true,
          ),
        ),
      )));

      expect(find.text('18m early'), findsOneWidget);
      expect(find.text('Reason required'), findsOneWidget);
    });

    testWidgets('on_time 은 배지 없이 "On time"', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item('s1', preview: const ClockInPreview(kind: 'on_time')),
      )));

      expect(find.text('On time'), findsOneWidget);
      expect(find.text('Reason required'), findsNothing);
    });

    testWidgets('프리뷰가 unknown 이면 줄 자체를 숨긴다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(item: _item('s1'))));

      expect(find.text('On time'), findsNothing);
      expect(find.textContaining('late'), findsNothing);
    });

    testWidgets('후보가 1개면 "Not this one" 이 없다 (탭을 늘리지 않는다)',
        (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(item: _item('s1'))));

      expect(find.text('Not this one'), findsNothing);
    });

    testWidgets('onChange 가 있으면 "Not this one" 이 뜨고 눌린다', (tester) async {
      await _surface(tester);
      var tapped = false;
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item('s1'),
        onChange: () => tapped = true,
      )));

      await tester.tap(find.text('Not this one'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('어제 영업일이면 Yesterday 배지 (D4)', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item('s1', operatingDay: '2026-08-12'),
        todayOperatingDay: '2026-08-13',
      )));

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('진행 중 shift 는 프리뷰 대신 "Clocked in" (D13)', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftSummaryCard(
        item: _item(
          's1',
          status: 'working',
          eligible: false,
          ineligibleReason: kIneligibleAlreadyClockedIn,
        ),
      )));

      expect(find.text('Clocked in'), findsOneWidget);
    });
  });

  group('ShiftPickerDialog — "이거 아님" 을 눌렀을 때만 열린다', () {
    testWidgets('각 항목의 시간대 + 프리뷰를 보여준다 (D3)', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        selectedScheduleId: 's1',
        items: [
          _item(
            's1',
            status: 'no_show',
            preview: const ClockInPreview(kind: 'late', minutesLate: 192),
          ),
          _item(
            's2',
            start: '17:00',
            end: '21:00',
            preview: const ClockInPreview(
              kind: 'early',
              minutesEarly: 235,
              reasonRequired: true,
            ),
          ),
        ],
        onPick: (_) {},
        onCancel: () {},
      )));

      expect(find.text('09:00 – 13:00'), findsOneWidget);
      expect(find.text('3h 12m late'), findsOneWidget);
      expect(find.text('17:00 – 21:00'), findsOneWidget);
      expect(find.text('3h 55m early'), findsOneWidget);
      expect(find.text('Reason required'), findsOneWidget);
    });

    testWidgets('고르면 그 항목이 콜백으로 온다', (tester) async {
      await _surface(tester);
      TodayAttendanceItem? picked;
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        items: [_item('s1'), _item('s2', start: '17:00', end: '21:00')],
        onPick: (i) => picked = i,
        onCancel: () {},
      )));

      await tester.tap(find.text('17:00 – 21:00'));
      await tester.pump();
      expect(picked!.scheduleId, 's2');
    });

    testWidgets('완료된 shift 는 보이되 선택은 막고 "Already done" (D14)',
        (tester) async {
      await _surface(tester);
      TodayAttendanceItem? picked;
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        items: [
          _item(
            's1',
            status: 'clocked_out',
            eligible: false,
            ineligibleReason: kIneligibleAlreadyCompleted,
          ),
          _item('s2', start: '17:00', end: '21:00'),
        ],
        onPick: (i) => picked = i,
        onCancel: () {},
      )));

      expect(find.text('09:00 – 13:00'), findsOneWidget);
      expect(find.text('Already done'), findsOneWidget);

      await tester.tap(find.text('09:00 – 13:00'), warnIfMissed: false);
      await tester.pump();
      expect(picked, isNull);
    });

    testWidgets('시각을 모르는 shift 도 목록에서 사라지지 않는다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        items: [_item('s1', start: null, end: null)],
        onPick: (_) {},
        onCancel: () {},
      )));

      expect(find.text('Time not set'), findsOneWidget);
    });

    testWidgets('재선택 사유가 있으면 상단에 안내한다', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        items: [_item('s1')],
        notice: 'That shift is no longer available. Pick another one.',
        onPick: (_) {},
        onCancel: () {},
      )));

      expect(
        find.text('That shift is no longer available. Pick another one.'),
        findsOneWidget,
      );
    });

    testWidgets('취소 → onCancel', (tester) async {
      await _surface(tester);
      var cancelled = false;
      await tester.pumpWidget(wrapForTest(ShiftPickerDialog(
        userName: 'Alice',
        items: [_item('s1')],
        onPick: (_) {},
        onCancel: () => cancelled = true,
      )));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });
}
