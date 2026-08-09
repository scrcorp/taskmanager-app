/// main_flow_transitions unit tests — Phase 5 Stage H-2.
///
/// state machine 전환 분기 전수.

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/models/early_clock_out_reason.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/models/tip_models.dart';
import 'package:attendance/providers/attendance_dashboard_provider.dart'
    show TodayStaffBreak;
import 'package:attendance/utils/main_flow_state.dart';
import 'package:attendance/utils/main_flow_transitions.dart';
import 'package:flutter_test/flutter_test.dart';

IdentifyResponse _user({String name = 'Marcus', String? status = 'working'}) =>
    IdentifyResponse(
      userId: 'u1',
      userName: name,
      todayStatus: status,
      currentBreak: null,
    );

const _tip = TipPayload(cardTips: 40, cashTipsKept: 10, distributions: []);

void main() {
  _earlyClockInTransitionTests();
  final now = DateTime(2026, 5, 22, 12, 0);
  final fourHoursLater = now.add(const Duration(hours: 4));
  final twoMinutesLater = now.add(const Duration(minutes: 2));

  group('startIdentifying', () {
    test('idle + PIN 입력 → identifying + PIN 보관', () {
      final s = MainFlowState.initial();
      final next = startIdentifying(s, '1234');
      expect(next.stage, MainFlowStage.identifying);
      expect(next.enteredPin, '1234');
    });
  });

  group('identifySucceeded', () {
    test('identifying + 응답 → confirming + user 세팅', () {
      final s = MainFlowState(stage: MainFlowStage.identifying, enteredPin: '1234');
      final u = _user();
      final next = identifySucceeded(s, u);
      expect(next.stage, MainFlowStage.confirming);
      expect(next.user?.userId, 'u1');
      // PIN 유지 (이후 clock action 시 사용)
      expect(next.enteredPin, '1234');
    });
  });

  group('identifyFailed', () {
    test('identifying + 에러 → error + 메시지', () {
      final s = MainFlowState(stage: MainFlowStage.identifying, enteredPin: '1234');
      final next = identifyFailed(s, 'Invalid PIN');
      expect(next.stage, MainFlowStage.error);
      expect(next.errorMessage, 'Invalid PIN');
    });
  });

  group('closeIdentity', () {
    test('confirming → idle, 모든 데이터 클리어', () {
      final s = MainFlowState(
        stage: MainFlowStage.confirming,
        enteredPin: '1234',
        user: _user(),
      );
      final next = closeIdentity(s);
      expect(next.stage, MainFlowStage.idle);
      expect(next.enteredPin, isNull);
      expect(next.user, isNull);
    });
  });

  group('confirmYes', () {
    test('confirming → choosingAction (user 유지)', () {
      final s = MainFlowState(
        stage: MainFlowStage.confirming,
        enteredPin: '1234',
        user: _user(),
      );
      final next = confirmYes(s);
      expect(next.stage, MainFlowStage.choosingAction);
      expect(next.user?.userId, 'u1');
      expect(next.enteredPin, '1234');
    });
  });

  group('pickAction', () {
    test('clock_in → submitting (early/tip 분기 없음)', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockIn, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.submitting);
      expect(next.pickedAction, AttendanceAction.clockIn);
    });

    test('breakShortPaid → submitting', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.breakShortPaid, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.submitting);
    });

    test('breakEnd → submitting', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.breakEnd, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.submitting);
    });

    test('clock_out + scheduledEnd null → tipEntry (early skip)', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockOut, scheduledEnd: null, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.tipEntry);
      expect(next.pickedAction, AttendanceAction.clockOut);
    });

    test('clock_out + scheduledEnd 곧 끝남(2분 남음) → tipEntry', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockOut, scheduledEnd: twoMinutesLater, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.tipEntry);
    });

    test('clock_out + scheduledEnd 멀음(4h 남음) → earlyReason', () {
      final s = MainFlowState(stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockOut, scheduledEnd: fourHoursLater, now: now, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.earlyReason);
      expect(next.pickedAction, AttendanceAction.clockOut);
    });
  });

  group('pickAction — store 설정 / break 초과 분기', () {
    test('clock_out + tip 설정 off → tipEntry 건너뛰고 바로 submitting', () {
      final s = MainFlowState(
          stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockOut,
          scheduledEnd: null, now: now, tipEntryEnabled: false);
      expect(next.stage, MainFlowStage.submitting);
      expect(next.pickedAction, AttendanceAction.clockOut);
    });

    test('clock_out + early + tip off → earlyReason 은 그대로 (early 가 우선)', () {
      final s = MainFlowState(
          stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(s, AttendanceAction.clockOut,
          scheduledEnd: fourHoursLater, now: now, tipEntryEnabled: false);
      expect(next.stage, MainFlowStage.earlyReason);
    });

    test('breakEnd + unpaid_meal 40분 → breakReason', () {
      final s = MainFlowState(
          stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(
        s,
        AttendanceAction.breakEnd,
        currentBreak: TodayStaffBreak(
          startedAt: now.subtract(const Duration(minutes: 40)),
          breakType: 'unpaid_meal',
        ),
        now: now,
        tipEntryEnabled: true,
      );
      expect(next.stage, MainFlowStage.breakReason);
      expect(next.pickedAction, AttendanceAction.breakEnd);
    });

    test('breakEnd + unpaid_meal 32분 → 사유 없이 submitting', () {
      final s = MainFlowState(
          stage: MainFlowStage.choosingAction, user: _user(), enteredPin: '1234');
      final next = pickAction(
        s,
        AttendanceAction.breakEnd,
        currentBreak: TodayStaffBreak(
          startedAt: now.subtract(const Duration(minutes: 32)),
          breakType: 'unpaid_meal',
        ),
        now: now,
        tipEntryEnabled: true,
      );
      expect(next.stage, MainFlowStage.submitting);
    });
  });

  group('submitBreakReason / cancelBreakReason', () {
    test('사유 제출 → submitting, reason 보관 (서버 body 로 나갈 값)', () {
      final s = MainFlowState(
        stage: MainFlowStage.breakReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.breakEnd,
      );
      final next = submitBreakReason(s, 'Waiting for coverage');
      expect(next.stage, MainFlowStage.submitting);
      expect(next.breakReason, 'Waiting for coverage');
      expect(next.pickedAction, AttendanceAction.breakEnd);
    });

    test('취소 → choosingAction (액션 다시 고를 수 있게)', () {
      final s = MainFlowState(
        stage: MainFlowStage.breakReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.breakEnd,
      );
      final next = cancelBreakReason(s);
      expect(next.stage, MainFlowStage.choosingAction);
      expect(next.pickedAction, isNull);
      expect(next.user?.userId, 'u1');
    });
  });

  group('submitEarlyReason — tip off', () {
    test('tip 설정 off 면 earlyReason 다음이 바로 submitting', () {
      final s = MainFlowState(
        stage: MainFlowStage.earlyReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = submitEarlyReason(
          s, EarlyClockOutReason.feelingUnwell, null, tipEntryEnabled: false);
      expect(next.stage, MainFlowStage.submitting);
      expect(next.earlyReason, EarlyClockOutReason.feelingUnwell);
    });
  });

  group('cancelAction', () {
    test('choosingAction → idle, 데이터 클리어', () {
      final s = MainFlowState(
        stage: MainFlowStage.choosingAction,
        enteredPin: '1234',
        user: _user(),
      );
      final next = cancelAction(s);
      expect(next.stage, MainFlowStage.idle);
      expect(next.enteredPin, isNull);
      expect(next.user, isNull);
    });
  });

  group('submitEarlyReason', () {
    test('earlyReason + reason+detail → tipEntry, reason/detail 보관', () {
      final s = MainFlowState(
        stage: MainFlowStage.earlyReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = submitEarlyReason(s, EarlyClockOutReason.feelingUnwell, null, tipEntryEnabled: true);
      expect(next.stage, MainFlowStage.tipEntry);
      expect(next.earlyReason, EarlyClockOutReason.feelingUnwell);
      expect(next.earlyDetail, isNull);
      expect(next.pickedAction, AttendanceAction.clockOut);
    });

    test('other reason + detail → detail 보관', () {
      final s = MainFlowState(
        stage: MainFlowStage.earlyReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = submitEarlyReason(s, EarlyClockOutReason.other, 'Doctor', tipEntryEnabled: true);
      expect(next.earlyReason, EarlyClockOutReason.other);
      expect(next.earlyDetail, 'Doctor');
    });
  });

  group('cancelEarly', () {
    test('earlyReason → choosingAction (action 다시 고를 수 있게, action 클리어)', () {
      final s = MainFlowState(
        stage: MainFlowStage.earlyReason,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = cancelEarly(s);
      expect(next.stage, MainFlowStage.choosingAction);
      expect(next.pickedAction, isNull);
      // user/pin 은 유지 (action sheet 다시 표시 위해)
      expect(next.user?.userId, 'u1');
      expect(next.enteredPin, '1234');
    });
  });

  group('submitTip', () {
    test('tipEntry + payload → submitting + tip 보관', () {
      final s = MainFlowState(
        stage: MainFlowStage.tipEntry,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = submitTip(s, _tip);
      expect(next.stage, MainFlowStage.submitting);
      expect(next.tip?.cardTips, 40);
    });
  });

  group('skipTip', () {
    test('tipEntry → submitting, tip 은 null', () {
      final s = MainFlowState(
        stage: MainFlowStage.tipEntry,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockOut,
      );
      final next = skipTip(s);
      expect(next.stage, MainFlowStage.submitting);
      expect(next.tip, isNull);
    });
  });

  group('submitSucceeded', () {
    test('submitting → success (user/action 유지 — SuccessModal 메시지용)', () {
      final s = MainFlowState(
        stage: MainFlowStage.submitting,
        user: _user(),
        pickedAction: AttendanceAction.clockIn,
      );
      final next = submitSucceeded(s);
      expect(next.stage, MainFlowStage.success);
      expect(next.user?.userId, 'u1');
      expect(next.pickedAction, AttendanceAction.clockIn);
    });
  });

  group('submitFailed', () {
    test('submitting → error + 메시지', () {
      final s = MainFlowState(stage: MainFlowStage.submitting, user: _user());
      final next = submitFailed(s, 'Server unreachable');
      expect(next.stage, MainFlowStage.error);
      expect(next.errorMessage, 'Server unreachable');
    });
  });

  group('closeSuccess', () {
    test('success → idle, 전부 클리어', () {
      final s = MainFlowState(
        stage: MainFlowStage.success,
        user: _user(),
        enteredPin: '1234',
        pickedAction: AttendanceAction.clockIn,
      );
      final next = closeSuccess(s);
      expect(next.stage, MainFlowStage.idle);
      expect(next.user, isNull);
      expect(next.enteredPin, isNull);
      expect(next.pickedAction, isNull);
    });
  });

  group('acknowledgeError', () {
    test('error → idle, 전부 클리어 + 메시지 제거', () {
      final s = MainFlowState(
        stage: MainFlowStage.error,
        user: _user(),
        enteredPin: '1234',
        errorMessage: 'oops',
      );
      final next = acknowledgeError(s);
      expect(next.stage, MainFlowStage.idle);
      expect(next.user, isNull);
      expect(next.enteredPin, isNull);
      expect(next.errorMessage, isNull);
    });
  });
}

// ── 조기 출근 강행 (서버가 400 code 로 사유를 요구하는 경로) ──────────────

void _earlyClockInTransitionTests() {
  const submitting = MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: '1234',
    pickedAction: AttendanceAction.clockIn,
  );

  group('requireEarlyClockInReason', () {
    test('submitting + 서버 거부 → earlyClockInReason + 이른 정도 보관', () {
      final next = requireEarlyClockInReason(submitting, 120);
      expect(next.stage, MainFlowStage.earlyClockInReason);
      expect(next.minutesEarly, 120);
      // 같은 clock_in 을 재시도해야 하므로 PIN/액션이 유지돼야 한다.
      expect(next.enteredPin, '1234');
      expect(next.pickedAction, AttendanceAction.clockIn);
    });
  });

  group('submitEarlyClockInReason', () {
    test('사유 제출 → submitting 으로 되돌아가 reason 과 함께 재시도', () {
      final next = submitEarlyClockInReason(
        requireEarlyClockInReason(submitting, 120),
        'Asked to come in early',
      );
      expect(next.stage, MainFlowStage.submitting);
      expect(next.earlyClockInReason, 'Asked to come in early');
      expect(next.pickedAction, AttendanceAction.clockIn);
    });
  });

  group('cancelEarlyClockInReason', () {
    test('취소 → 액션 선택으로. 출근은 성립하지 않는다', () {
      final next = cancelEarlyClockInReason(
        requireEarlyClockInReason(submitting, 120),
      );
      expect(next.stage, MainFlowStage.choosingAction);
      expect(next.earlyClockInReason, isNull);
    });
  });
}
