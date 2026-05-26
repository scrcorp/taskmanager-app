/// Main flow state transitions — Phase 5 Stage H-2.
///
/// 모든 함수는 pure: (state, input) → new state. IO 없음.
/// IO (API 호출) 는 main_screen state holder 가 담당 — transition 호출 사이에 수행.

import '../models/attendance_action.dart';
import '../models/early_clock_out_reason.dart';
import '../models/identify_response.dart';
import '../models/tip_models.dart';
import 'flow_decisions.dart';
import 'main_flow_state.dart';

MainFlowState startIdentifying(MainFlowState s, String pin) {
  return MainFlowState(
    stage: MainFlowStage.identifying,
    enteredPin: pin,
  );
}

MainFlowState identifySucceeded(MainFlowState s, IdentifyResponse user) {
  return MainFlowState(
    stage: MainFlowStage.confirming,
    enteredPin: s.enteredPin,
    user: user,
  );
}

MainFlowState identifyFailed(MainFlowState s, String message) {
  return MainFlowState(
    stage: MainFlowStage.error,
    errorMessage: message,
  );
}

MainFlowState closeIdentity(MainFlowState s) {
  return MainFlowState.initial();
}

MainFlowState confirmYes(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
  );
}

MainFlowState pickAction(
  MainFlowState s,
  AttendanceAction action, {
  DateTime? scheduledEnd,
  required DateTime now,
}) {
  // clock_out → early/tip 분기
  if (action == AttendanceAction.clockOut) {
    final showEarly = shouldShowEarlyClockOutDialog(
      action: action,
      scheduledEnd: scheduledEnd,
      now: now,
    );
    return MainFlowState(
      stage: showEarly ? MainFlowStage.earlyReason : MainFlowStage.tipEntry,
      enteredPin: s.enteredPin,
      user: s.user,
      pickedAction: action,
    );
  }
  // 기타: 바로 submitting
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: action,
  );
}

MainFlowState cancelAction(MainFlowState s) {
  return MainFlowState.initial();
}

MainFlowState submitEarlyReason(
  MainFlowState s,
  EarlyClockOutReason reason,
  String? detail,
) {
  return MainFlowState(
    stage: MainFlowStage.tipEntry,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyReason: reason,
    earlyDetail: detail,
  );
}

MainFlowState cancelEarly(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    // pickedAction / earlyReason / earlyDetail 는 클리어
  );
}

MainFlowState submitTip(MainFlowState s, TipPayload payload) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyReason: s.earlyReason,
    earlyDetail: s.earlyDetail,
    tip: payload,
  );
}

MainFlowState skipTip(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyReason: s.earlyReason,
    earlyDetail: s.earlyDetail,
    // tip 은 null 유지
  );
}

MainFlowState submitSucceeded(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.success,
    user: s.user,
    pickedAction: s.pickedAction,
  );
}

MainFlowState submitFailed(MainFlowState s, String message) {
  return MainFlowState(
    stage: MainFlowStage.error,
    errorMessage: message,
  );
}

MainFlowState closeSuccess(MainFlowState s) {
  return MainFlowState.initial();
}

MainFlowState acknowledgeError(MainFlowState s) {
  return MainFlowState.initial();
}
