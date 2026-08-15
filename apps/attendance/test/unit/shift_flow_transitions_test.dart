/// shift 선택 · 겹침 · 요청자 재시도 상태 전이 unit test (페이즈 ④⑤⑥).
///
/// 재시도 형태가 셋 다 같아야 한다는 것이 이 파일의 요점이다:
/// 조기 출근 사유 / 겹침 확인 / 요청자 id 제거 — 전부 "같은 요청에 필드 하나 더 붙여
/// 다시 보낸다". 형태가 갈리면 상태기계에 새 개념이 생기고, 그때부터 어느 경로가
/// 어떤 값을 들고 가는지 아무도 못 따라간다.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/utils/main_flow_state.dart';
import 'package:attendance/utils/main_flow_transitions.dart' as flow;
import 'package:flutter_test/flutter_test.dart';

TodayAttendanceItem _item(
  String id, {
  String status = 'upcoming',
  bool eligible = true,
}) =>
    TodayAttendanceItem(
      scheduleId: id,
      status: status,
      clockInEligible: eligible,
      ineligibleReason: eligible ? null : 'already_completed',
    );

IdentifyResponse _resp(
  List<TodayAttendanceItem> items, {
  String? defaultScheduleId,
}) =>
    IdentifyResponse(
      userId: 'u1',
      userName: 'Alice',
      todayStatus: items.isEmpty ? null : items.first.status,
      todayAttendances: items,
      defaultScheduleId: defaultScheduleId,
    );

MainFlowState _atAction(IdentifyResponse resp) {
  final s = flow.identifySucceeded(
    flow.startIdentifying(MainFlowState.initial(), '1234'),
    resp,
    at: DateTime(2026, 8, 13, 9, 0),
  );
  return flow.confirmYes(s);
}

void main() {
  group('identifySucceeded — 서버가 정한 기본 shift 를 고른다', () {
    test('default_schedule_id 를 따른다 (앱이 자체 우선순위를 만들지 않는다)', () {
      final s = flow.identifySucceeded(
        MainFlowState.initial(),
        _resp([_item('s1'), _item('s2')], defaultScheduleId: 's2'),
      );
      expect(s.stage, MainFlowStage.confirming);
      expect(s.user!.selectedScheduleId, 's2');
    });

    test('identifiedAt 을 들고 간다 (프리뷰 신선도 판단용)', () {
      final at = DateTime(2026, 8, 13, 9, 0);
      final s = flow.identifySucceeded(
        MainFlowState.initial(),
        _resp([_item('s1')]),
        at: at,
      );
      expect(s.identifiedAt, at);
    });
  });

  group('shift picker (④)', () {
    test('"이거 아님" → 목록 단계로 (그전엔 목록을 띄우지 않는다)', () {
      final s = flow.openShiftPicker(_atAction(_resp([_item('s1'), _item('s2')])));
      expect(s.stage, MainFlowStage.choosingShift);
      expect(s.user!.todayAttendances.length, 2);
    });

    test('고르면 선택이 바뀌고 액션 선택으로 돌아온다', () {
      final resp = _resp([_item('s1'), _item('s2')], defaultScheduleId: 's1');
      final picking = flow.openShiftPicker(_atAction(resp));
      final s = flow.chooseShift(picking, resp.todayAttendances[1]);
      expect(s.stage, MainFlowStage.choosingAction);
      expect(s.user!.selectedScheduleId, 's2');
      // 목록 자체는 유지 — 다시 열 수 있어야 한다.
      expect(s.user!.todayAttendances.length, 2);
    });

    test('고를 수 없는 항목은 선택이 바뀌지 않는다 (서버 거부 400 을 미리 막는다)', () {
      final resp = _resp(
        [_item('s1'), _item('s2', status: 'clocked_out', eligible: false)],
        defaultScheduleId: 's1',
      );
      final picking = flow.openShiftPicker(_atAction(resp));
      final s = flow.chooseShift(picking, resp.todayAttendances[1]);
      expect(s.stage, MainFlowStage.choosingAction);
      expect(s.user!.selectedScheduleId, 's1');
    });

    test('취소 → 선택 그대로 액션 선택으로', () {
      final resp = _resp([_item('s1'), _item('s2')], defaultScheduleId: 's1');
      final s = flow.cancelShiftPicker(flow.openShiftPicker(_atAction(resp)));
      expect(s.stage, MainFlowStage.choosingAction);
      expect(s.user!.selectedScheduleId, 's1');
    });
  });

  group('겹침 clock-in (⑤)', () {
    MainFlowState _submitting() {
      final base = _atAction(_resp([_item('s1'), _item('s2')]));
      return flow.pickAction(
        base,
        AttendanceAction.clockIn,
        now: DateTime(2026, 8, 13, 9, 0),
        tipEntryEnabled: false,
      );
    }

    test('확인 요구 400 → 확인 단계, 아직 allow_overlap 은 켜지 않는다', () {
      final s = flow.requireOverlapConfirm(_submitting(), {
        'open_scheduled_start_display': '09:00',
        'open_scheduled_end_display': '13:00',
      });
      expect(s.stage, MainFlowStage.overlapConfirm);
      expect(s.allowOverlap, isFalse);
      expect(s.pickedAction, AttendanceAction.clockIn);
      expect(s.overlapDetail!['open_scheduled_start_display'], '09:00');
    });

    test('확인 → 같은 요청에 allow_overlap 만 붙여 재전송', () {
      final s = flow.confirmOverlap(flow.requireOverlapConfirm(_submitting(), null));
      expect(s.stage, MainFlowStage.submitting);
      expect(s.allowOverlap, isTrue);
      expect(s.pickedAction, AttendanceAction.clockIn);
    });

    test('취소 → 출근은 성립하지 않고 액션 선택으로 (플래그도 꺼진다)', () {
      final s = flow.cancelOverlap(flow.requireOverlapConfirm(_submitting(), null));
      expect(s.stage, MainFlowStage.choosingAction);
      expect(s.allowOverlap, isFalse);
      expect(s.pickedAction, isNull);
    });

    test('성공 응답이 겹침이면 성공 화면에 안내가 붙는다', () {
      final s = flow.submitSucceeded(_submitting(), overlapped: true);
      expect(s.stage, MainFlowStage.success);
      expect(s.overlapped, isTrue);
    });

    test('겹침 확인은 사유 단계를 지나도 유지된다 (한 번 확인한 걸 또 묻지 않는다)', () {
      final confirmed = flow.confirmOverlap(
        flow.requireOverlapConfirm(_submitting(), null),
      );
      final asked = flow.requireEarlyClockInReason(confirmed, 30);
      expect(asked.allowOverlap, isTrue);
      final resubmitted = flow.submitEarlyClockInReason(
        asked,
        'Asked to come in early (John Kim)',
        requestedBy: 'u-gm',
      );
      expect(resubmitted.allowOverlap, isTrue);
      expect(resubmitted.earlyClockInRequestedBy, 'u-gm');
    });
  });

  group('early 사유 + 요청자 (⑥)', () {
    MainFlowState _asked() {
      final base = _atAction(_resp([_item('s1')]));
      final submitting = flow.pickAction(
        base,
        AttendanceAction.clockIn,
        now: DateTime(2026, 8, 13, 9, 0),
        tipEntryEnabled: false,
      );
      return flow.requireEarlyClockInReason(submitting, 125);
    }

    test('사유 + 요청자 id 를 함께 들고 재제출한다 (D9 이중 기록)', () {
      final s = flow.submitEarlyClockInReason(
        _asked(),
        'Asked to come in early (John Kim)',
        requestedBy: 'u-gm',
      );
      expect(s.stage, MainFlowStage.submitting);
      expect(s.earlyClockInReason, 'Asked to come in early (John Kim)');
      expect(s.earlyClockInRequestedBy, 'u-gm');
    });

    test('직접 입력은 id 없이 문자열만 (명단 밖 사람)', () {
      final s = flow.submitEarlyClockInReason(
        _asked(),
        'Asked to come in early (Sam from HQ)',
      );
      expect(s.earlyClockInRequestedBy, isNull);
    });

    test('invalid_reason_user → id 만 떼고 재시도, 사유 문자열은 그대로', () {
      final submitted = flow.submitEarlyClockInReason(
        _asked(),
        'Asked to come in early (John Kim)',
        requestedBy: 'u-gm',
      );
      final retry = flow.retryWithoutRequester(submitted);
      expect(retry.stage, MainFlowStage.submitting);
      expect(retry.earlyClockInReason, 'Asked to come in early (John Kim)');
      expect(retry.earlyClockInRequestedBy, isNull);
      // 조용히 버리지 않는다 — 성공 화면에서 알린다.
      expect(retry.requesterDropped, isTrue);
    });

    test('재시도 플래그는 성공 화면까지 살아남는다', () {
      final retry = flow.retryWithoutRequester(
        flow.submitEarlyClockInReason(_asked(), 'x', requestedBy: 'u-gm'),
      );
      expect(flow.submitSucceeded(retry).requesterDropped, isTrue);
    });

    test('사유 취소 → 출근 성립 안 함 + 요청자도 남지 않는다', () {
      final cancelled = flow.cancelEarlyClockInReason(
        flow.submitEarlyClockInReason(_asked(), 'x', requestedBy: 'u-gm'),
      );
      expect(cancelled.stage, MainFlowStage.choosingAction);
      expect(cancelled.earlyClockInRequestedBy, isNull);
      expect(cancelled.pickedAction, isNull);
    });
  });
}
