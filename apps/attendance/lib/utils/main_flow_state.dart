/// Main screen flow state machine — Phase 5 Stage H-2.
///
/// PIN-first 흐름의 stage 와 immutable state.
/// transition 은 별도 함수 (`main_flow_transitions.dart`) 에서 수행.

import '../models/attendance_action.dart';
import '../models/early_clock_out_reason.dart';
import '../models/identify_response.dart';
import '../models/tip_models.dart';

/// 메인 화면의 진행 단계.
///   - idle: 초기 상태, PIN numpad 만 표시
///   - identifying: identify-by-pin API 진행 중 (loading)
///   - confirming: IdentityConfirmDialog
///   - choosingAction: ActionSheet
///   - earlyReason: EarlyClockOutDialog (clock_out 일찍 시)
///   - tipEntry: TipEntryDialog (clock_out 후)
///   - submitting: clock action API 진행 중 (loading)
///   - success: SuccessModal
///   - error: 에러 표시 (전환 어느 단계든 fail 시)
enum MainFlowStage {
  idle,
  identifying,
  confirming,
  choosingAction,
  earlyReason,
  tipEntry,
  submitting,
  success,
  error,
}

class MainFlowState {
  final MainFlowStage stage;
  final String? enteredPin;
  final IdentifyResponse? user;
  final AttendanceAction? pickedAction;
  final EarlyClockOutReason? earlyReason;
  final String? earlyDetail;
  final TipPayload? tip;
  final String? errorMessage;

  const MainFlowState({
    required this.stage,
    this.enteredPin,
    this.user,
    this.pickedAction,
    this.earlyReason,
    this.earlyDetail,
    this.tip,
    this.errorMessage,
  });

  /// 초기 idle 상태.
  factory MainFlowState.initial() =>
      const MainFlowState(stage: MainFlowStage.idle);

  /// 일부 필드만 갱신. null 을 명시적으로 보내고 싶을 땐 sentinel 패턴 필요하지만
  /// 여기선 transition 이 새 state 를 통째로 만들어 반환하므로 copyWith 가 단순.
  MainFlowState copyWith({
    MainFlowStage? stage,
    String? enteredPin,
    IdentifyResponse? user,
    AttendanceAction? pickedAction,
    EarlyClockOutReason? earlyReason,
    String? earlyDetail,
    TipPayload? tip,
    String? errorMessage,
  }) {
    return MainFlowState(
      stage: stage ?? this.stage,
      enteredPin: enteredPin ?? this.enteredPin,
      user: user ?? this.user,
      pickedAction: pickedAction ?? this.pickedAction,
      earlyReason: earlyReason ?? this.earlyReason,
      earlyDetail: earlyDetail ?? this.earlyDetail,
      tip: tip ?? this.tip,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MainFlowState &&
          other.stage == stage &&
          other.enteredPin == enteredPin &&
          other.user?.userId == user?.userId &&
          other.pickedAction == pickedAction &&
          other.earlyReason == earlyReason &&
          other.earlyDetail == earlyDetail &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(
        stage,
        enteredPin,
        user?.userId,
        pickedAction,
        earlyReason,
        earlyDetail,
        errorMessage,
      );

  @override
  String toString() =>
      'MainFlowState(stage=$stage, user=${user?.userName}, action=$pickedAction, err=$errorMessage)';
}
