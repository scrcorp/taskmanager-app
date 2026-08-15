/// Main flow state transitions — Phase 5 Stage H-2.
///
/// 모든 함수는 pure: (state, input) → new state. IO 없음.
/// IO (API 호출) 는 main_screen state holder 가 담당 — transition 호출 사이에 수행.

import '../models/attendance_action.dart';
import '../models/early_clock_out_reason.dart';
import '../models/identify_response.dart';
import '../models/tip_models.dart';
import '../providers/attendance_dashboard_provider.dart' show TodayStaffBreak;
import 'flow_decisions.dart';
import 'main_flow_state.dart';
import 'shift_pick_logic.dart';

MainFlowState startIdentifying(MainFlowState s, String pin) {
  return MainFlowState(
    stage: MainFlowStage.identifying,
    enteredPin: pin,
  );
}

MainFlowState identifySucceeded(
  MainFlowState s,
  IdentifyResponse user, {
  DateTime? at,
}) {
  // 기본 shift 는 **서버가 정한다**(`default_schedule_id`, 계약 §1.7).
  // 앱이 자체 우선순위를 만들면 그게 또 하나의 규칙이 되어 원인 A 가 되돌아온다.
  final defaultItem = pickDefaultShift(user);
  final selected =
      defaultItem != null ? user.withSelectedSchedule(defaultItem) : user;
  return MainFlowState(
    stage: MainFlowStage.confirming,
    enteredPin: s.enteredPin,
    user: selected,
    identifiedAt: at,
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
    identifiedAt: s.identifiedAt,
  );
}

/// "이거 아님" — 그때서야 목록을 연다 (D14).
MainFlowState openShiftPicker(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingShift,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
  );
}

/// 목록에서 shift 를 골랐다 → 액션 선택으로 돌아간다.
///
/// 고를 수 없는 항목(완료/이미 출근)은 화면에서 탭이 막혀 있지만, 방어적으로
/// 여기서도 무시한다 — 서버가 어차피 거부하고 그 400 은 사용자에게 설명이 안 된다.
MainFlowState chooseShift(MainFlowState s, TodayAttendanceItem item) {
  final user = s.user;
  if (user == null || !isShiftSelectable(item)) {
    return MainFlowState(
      stage: MainFlowStage.choosingAction,
      enteredPin: s.enteredPin,
      user: user,
      identifiedAt: s.identifiedAt,
    );
  }
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: user.withSelectedSchedule(item),
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState cancelShiftPicker(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState pickAction(
  MainFlowState s,
  AttendanceAction action, {
  DateTime? scheduledEnd,
  TodayStaffBreak? currentBreak,
  required DateTime now,
  required bool tipEntryEnabled,
}) {
  // clock_out → early/tip 분기
  if (action == AttendanceAction.clockOut) {
    final showEarly = shouldShowEarlyClockOutDialog(
      action: action,
      scheduledEnd: scheduledEnd,
      now: now,
    );
    final showTip = shouldShowTipEntry(action, tipEntryEnabled: tipEntryEnabled);
    return MainFlowState(
      stage: showEarly
          ? MainFlowStage.earlyReason
          : (showTip ? MainFlowStage.tipEntry : MainFlowStage.submitting),
      enteredPin: s.enteredPin,
      user: s.user,
      pickedAction: action,
      identifiedAt: s.identifiedAt,
    );
  }
  // break_end 가 허용 시간을 넘겼으면 사유 입력 먼저 — 없으면 서버가 거부한다.
  if (shouldShowBreakReasonDialog(
    action: action,
    currentBreak: currentBreak,
    now: now,
  )) {
    return MainFlowState(
      stage: MainFlowStage.breakReason,
      enteredPin: s.enteredPin,
      user: s.user,
      pickedAction: action,
      identifiedAt: s.identifiedAt,
    );
  }
  // 기타: 바로 submitting
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: action,
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState submitBreakReason(MainFlowState s, String reason) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    breakReason: reason,
    identifiedAt: s.identifiedAt,
  );
}

/// 서버가 조기 출근 사유를 요구했을 때 (400 code) — 사유 입력 단계로.
///
/// clock_out 과 달리 앱이 미리 판정하지 않는다. threshold 가 서버 설정이라
/// 한 번 제출해 보고 거부 코드를 받아야 알 수 있다.
MainFlowState requireEarlyClockInReason(MainFlowState s, int minutesEarly) {
  return MainFlowState(
    stage: MainFlowStage.earlyClockInReason,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    minutesEarly: minutesEarly,
    // 겹침 확인은 사유 단계를 지나도 유지된다 — 한 번 확인한 걸 또 묻지 않는다.
    allowOverlap: s.allowOverlap,
    identifiedAt: s.identifiedAt,
  );
}

/// 조기 출근 사유 제출 → 같은 clock_in 을 reason(+요청자 id) 과 함께 재시도.
MainFlowState submitEarlyClockInReason(
  MainFlowState s,
  String reason, {
  String? requestedBy,
}) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    minutesEarly: s.minutesEarly,
    earlyClockInReason: reason,
    earlyClockInRequestedBy: requestedBy,
    allowOverlap: s.allowOverlap,
    identifiedAt: s.identifiedAt,
  );
}

/// 서버가 요청자 id 를 거부했다 (§5 `invalid_reason_user`).
///
/// **id 만 떼고 같은 사유 문자열로 1회 재시도**한다. 조용히 버리는 게 아니라
/// [MainFlowState.requesterDropped] 로 남겨 성공 화면에서 알린다 —
/// "조용한 실패 금지" 와 "키오스크에서 출근이 막히면 안 된다" 를 둘 다 만족시킨다.
MainFlowState retryWithoutRequester(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    minutesEarly: s.minutesEarly,
    earlyClockInReason: s.earlyClockInReason,
    // requestedBy 를 의도적으로 비운다.
    allowOverlap: s.allowOverlap,
    requesterDropped: true,
    identifiedAt: s.identifiedAt,
  );
}

/// 사유 입력 취소 — 출근은 성립하지 않는다. 액션 선택으로 되돌린다.
MainFlowState cancelEarlyClockInReason(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
  );
}

/// 다른 shift 가 열려 있는데 또 찍으려 한다 (§3.2 확인 요구 400).
MainFlowState requireOverlapConfirm(
  MainFlowState s,
  Map<String, dynamic>? detail,
) {
  return MainFlowState(
    stage: MainFlowStage.overlapConfirm,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyClockInReason: s.earlyClockInReason,
    earlyClockInRequestedBy: s.earlyClockInRequestedBy,
    minutesEarly: s.minutesEarly,
    overlapDetail: detail,
    requesterDropped: s.requesterDropped,
    identifiedAt: s.identifiedAt,
  );
}

/// 경고를 보고 확인했다 → 같은 요청에 `allow_overlap: true` 만 붙여 재전송.
MainFlowState confirmOverlap(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyClockInReason: s.earlyClockInReason,
    earlyClockInRequestedBy: s.earlyClockInRequestedBy,
    minutesEarly: s.minutesEarly,
    allowOverlap: true,
    requesterDropped: s.requesterDropped,
    identifiedAt: s.identifiedAt,
  );
}

/// 겹침 확인 취소 — 출근은 성립하지 않는다.
MainFlowState cancelOverlap(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState cancelBreakReason(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState cancelAction(MainFlowState s) {
  return MainFlowState.initial();
}

MainFlowState submitEarlyReason(
  MainFlowState s,
  EarlyClockOutReason reason,
  String? detail, {
  required bool tipEntryEnabled,
}) {
  return MainFlowState(
    stage: tipEntryEnabled ? MainFlowStage.tipEntry : MainFlowStage.submitting,
    enteredPin: s.enteredPin,
    user: s.user,
    pickedAction: s.pickedAction,
    earlyReason: reason,
    earlyDetail: detail,
    identifiedAt: s.identifiedAt,
  );
}

MainFlowState cancelEarly(MainFlowState s) {
  return MainFlowState(
    stage: MainFlowStage.choosingAction,
    enteredPin: s.enteredPin,
    user: s.user,
    identifiedAt: s.identifiedAt,
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
    identifiedAt: s.identifiedAt,
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
    identifiedAt: s.identifiedAt,
  );
}

/// [overlapped] 는 서버 응답의 `overlap.is_overlapping` 그대로 (§3.4).
MainFlowState submitSucceeded(MainFlowState s, {bool overlapped = false}) {
  return MainFlowState(
    stage: MainFlowStage.success,
    user: s.user,
    pickedAction: s.pickedAction,
    overlapped: overlapped,
    requesterDropped: s.requesterDropped,
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
