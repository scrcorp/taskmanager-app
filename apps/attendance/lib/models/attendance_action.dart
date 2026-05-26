/// Clock 액션 — Phase 5 Main 의 PIN 식별 → 액션 선택 흐름에서 사용.
///
/// 별도 파일로 분리한 이유: ActionSheet widget 이 enum 을 받는데, widget 이
/// screen 을 import 하면 Stage H 에서 screen 이 widget 을 import 할 때 cycle
/// 발생. enum 만 따로 두고 양쪽에서 import.

enum AttendanceAction {
  clockIn,
  clockOut,
  breakShortPaid,
  breakLongUnpaid,
  breakEnd,
}

extension AttendanceActionX on AttendanceAction {
  /// 서버에 전달할 action 문자열 (`performClockAction` 의 action 파라미터).
  String get apiKey {
    switch (this) {
      case AttendanceAction.clockIn:
        return 'clock-in';
      case AttendanceAction.clockOut:
        return 'clock-out';
      case AttendanceAction.breakShortPaid:
      case AttendanceAction.breakLongUnpaid:
        return 'break-start';
      case AttendanceAction.breakEnd:
        return 'break-end';
    }
  }

  /// break-start 에 첨부할 break_type ('paid_10min' | 'unpaid_meal').
  /// 그 외 action 은 null.
  String? get breakType {
    switch (this) {
      case AttendanceAction.breakShortPaid:
        return 'paid_10min';
      case AttendanceAction.breakLongUnpaid:
        return 'unpaid_meal';
      case AttendanceAction.clockIn:
      case AttendanceAction.clockOut:
      case AttendanceAction.breakEnd:
        return null;
    }
  }

  /// UI fallback 라벨 (영어). i18n 은 main_screen 의 localizedLabel 사용.
  String get label {
    switch (this) {
      case AttendanceAction.clockIn:
        return 'Clock In';
      case AttendanceAction.clockOut:
        return 'Clock Out';
      case AttendanceAction.breakShortPaid:
        return '10min Break';
      case AttendanceAction.breakLongUnpaid:
        return 'Meal Break';
      case AttendanceAction.breakEnd:
        return 'End Break';
    }
  }
}
