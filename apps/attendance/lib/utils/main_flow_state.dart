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
///   - choosingShift: ShiftPickerDialog ("이거 아님" 을 눌렀을 때만, D14).
///     기본 제시 카드가 ActionSheet 안에 있으므로 정상 출근자는 이 단계를 안 거친다
///   - overlapConfirm: 다른 shift 가 열려 있는데 또 찍으려 할 때의 확인 (D15/§3.2)
///   - earlyReason: EarlyClockOutDialog (clock_out 일찍 시)
///   - earlyClockInReason: EarlyClockInDialog (clock_in 이 예정보다 이를 때).
///     clock_out 과 달리 **서버가 판정한다** — threshold 가 서버 설정이라 앱이
///     미리 알 수 없다. 그래서 한 번 제출해 400(code) 을 받고 이 단계로 온다.
///   - breakReason: BreakReasonDialog (break_end 가 허용 시간 초과 시)
///   - tipEntry: TipEntryDialog (clock_out 후)
///   - submitting: clock action API 진행 중 (loading)
///   - success: SuccessModal
///   - error: 에러 표시 (전환 어느 단계든 fail 시)
enum MainFlowStage {
  idle,
  identifying,
  confirming,
  choosingAction,
  choosingShift,
  overlapConfirm,
  earlyReason,
  earlyClockInReason,
  breakReason,
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
  /// break_end 초과 사유 — 서버 body 의 reason 으로 그대로 전달된다.
  final String? breakReason;
  /// 조기 출근 사유 — clock_in body 의 reason 으로 전달된다.
  final String? earlyClockInReason;
  /// 조기 출근을 요청한 사람의 user_id (계약 §2.1). "직접 입력" 이면 null.
  final String? earlyClockInRequestedBy;
  /// 예정보다 몇 분 이른지 (서버 detail.minutes_early) — 사유 화면 헤더용.
  final int? minutesEarly;
  /// 겹침 clock-in 을 사용자가 확인했는가 (계약 §3.1 `allow_overlap`).
  /// **확인 다이얼로그를 거쳤을 때만** true — 기본값 false 를 유지하는 것이
  /// 키오스크 더블탭·재시도 중복 row 를 막는 기존 가드를 살려두는 방법이다.
  final bool allowOverlap;
  /// 겹침 확인 400 의 detail — 안내 문구에 쓸 열린 shift 시간대가 들어 있다.
  final Map<String, dynamic>? overlapDetail;
  /// 방금 찍은 출근이 다른 shift 와 겹쳤는가 (성공 화면 안내 트리거, §3.4).
  final bool overlapped;
  /// 서버가 요청자 id 를 거부해 id 없이 재시도했는가 (§5 `invalid_reason_user`).
  /// 조용히 버리지 않고 성공 화면에 한 줄로 알린다.
  final bool requesterDropped;
  final TipPayload? tip;
  final String? errorMessage;
  /// identify 응답을 **받은 로컬 시각** — 프리뷰 신선도 판단용(§1.2).
  final DateTime? identifiedAt;

  const MainFlowState({
    required this.stage,
    this.enteredPin,
    this.user,
    this.pickedAction,
    this.earlyReason,
    this.earlyDetail,
    this.breakReason,
    this.earlyClockInReason,
    this.earlyClockInRequestedBy,
    this.minutesEarly,
    this.allowOverlap = false,
    this.overlapDetail,
    this.overlapped = false,
    this.requesterDropped = false,
    this.tip,
    this.errorMessage,
    this.identifiedAt,
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
    String? breakReason,
    String? earlyClockInReason,
    String? earlyClockInRequestedBy,
    int? minutesEarly,
    bool? allowOverlap,
    Map<String, dynamic>? overlapDetail,
    bool? overlapped,
    bool? requesterDropped,
    TipPayload? tip,
    String? errorMessage,
    DateTime? identifiedAt,
  }) {
    return MainFlowState(
      stage: stage ?? this.stage,
      enteredPin: enteredPin ?? this.enteredPin,
      user: user ?? this.user,
      pickedAction: pickedAction ?? this.pickedAction,
      earlyReason: earlyReason ?? this.earlyReason,
      earlyDetail: earlyDetail ?? this.earlyDetail,
      breakReason: breakReason ?? this.breakReason,
      earlyClockInReason: earlyClockInReason ?? this.earlyClockInReason,
      earlyClockInRequestedBy:
          earlyClockInRequestedBy ?? this.earlyClockInRequestedBy,
      minutesEarly: minutesEarly ?? this.minutesEarly,
      allowOverlap: allowOverlap ?? this.allowOverlap,
      overlapDetail: overlapDetail ?? this.overlapDetail,
      overlapped: overlapped ?? this.overlapped,
      requesterDropped: requesterDropped ?? this.requesterDropped,
      tip: tip ?? this.tip,
      errorMessage: errorMessage ?? this.errorMessage,
      identifiedAt: identifiedAt ?? this.identifiedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MainFlowState &&
          other.stage == stage &&
          other.enteredPin == enteredPin &&
          other.user?.userId == user?.userId &&
          other.user?.selectedScheduleId == user?.selectedScheduleId &&
          other.pickedAction == pickedAction &&
          other.earlyReason == earlyReason &&
          other.earlyDetail == earlyDetail &&
          other.breakReason == breakReason &&
          other.earlyClockInReason == earlyClockInReason &&
          other.earlyClockInRequestedBy == earlyClockInRequestedBy &&
          other.minutesEarly == minutesEarly &&
          other.allowOverlap == allowOverlap &&
          other.overlapped == overlapped &&
          other.requesterDropped == requesterDropped &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(
        stage,
        enteredPin,
        user?.userId,
        user?.selectedScheduleId,
        pickedAction,
        earlyReason,
        earlyDetail,
        breakReason,
        earlyClockInReason,
        earlyClockInRequestedBy,
        minutesEarly,
        allowOverlap,
        overlapped,
        requesterDropped,
        errorMessage,
      );

  @override
  String toString() =>
      'MainFlowState(stage=$stage, user=${user?.userName}, action=$pickedAction, err=$errorMessage)';
}
