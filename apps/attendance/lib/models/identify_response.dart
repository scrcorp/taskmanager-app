/// PIN 식별 응답 모델 — POST /attendance/identify-by-pin.
///
/// Phase 3: user_id, user_name, today_status.
/// Stage J: current_break, scheduled_end.
/// Issue 8: today_attendances — 한 직원의 오늘 모든 schedule. 2+ 건이면 picker.
/// 2026-08-13 shift 선택 계약 §1.2: default_schedule_id / server_time /
///   항목별 attendance_id · operating_day · clock_in · 선택 가능 여부 · 판정 프리뷰.

import '../providers/attendance_dashboard_provider.dart';

/// 지금 이 shift 로 출근하면 어떻게 기록되는지 — **서버가 계산해서 내려준다**(계약 §1.4).
///
/// 앱이 다시 계산하지 않는다. 초 버림 지점이 하나 더 생기면 화면과 기록이 갈린다(R0-1).
class ClockInPreview {
  /// "early" | "on_time" | "late" | "unknown".
  /// unknown = 스케줄 시각 미상 → 앱은 프리뷰 줄 자체를 숨긴다.
  final String kind;

  /// 예정보다 이른 분. kind != early 면 0.
  final int minutesEarly;

  /// 예정보다 늦은 분. kind != late 면 0.
  final int minutesLate;

  /// 지금 고르면 사유 입력이 요구되는가 (kind == early).
  final bool reasonRequired;

  const ClockInPreview({
    required this.kind,
    this.minutesEarly = 0,
    this.minutesLate = 0,
    this.reasonRequired = false,
  });

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory ClockInPreview.fromJson(Map<String, dynamic> json) {
    return ClockInPreview(
      kind: json['kind']?.toString() ?? 'unknown',
      minutesEarly: _int(json['minutes_early']),
      minutesLate: _int(json['minutes_late']),
      reasonRequired: json['reason_required'] == true,
    );
  }
}

/// 오늘 attendance(=schedule) 1건 — 다중 schedule picker 용 (Issue 8).
class TodayAttendanceItem {
  final String? scheduleId;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? scheduledStartDisplay;
  final String? scheduledEndDisplay;
  final TodayStaffBreak? currentBreak;

  /// attendance row 식별자. row 가 아직 없으면 null.
  final String? attendanceId;

  /// 영업일 라벨 "YYYY-MM-DD". 오늘과 다르면 앱이 "Yesterday" 배지를 붙인다(D4).
  final String? operatingDay;

  final DateTime? clockIn;
  final String? clockInDisplay;

  /// 이 shift 를 clock-in 대상으로 고를 수 있는가 (계약 §1.5).
  final bool clockInEligible;

  /// 못 고르는 이유 — "already_completed" | "already_clocked_in".
  final String? ineligibleReason;

  /// 서버가 정한 기본 shift 인가 (default_schedule_id 와 같은 항목).
  final bool isDefault;

  /// 지금 다른 shift 와 겹쳐 열려 있는가 (계약 §3.5).
  final bool overlapping;

  /// 판정 프리뷰. clockInEligible == false 면 항상 null.
  final ClockInPreview? clockInPreview;

  const TodayAttendanceItem({
    required this.scheduleId,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledStartDisplay,
    this.scheduledEndDisplay,
    this.currentBreak,
    this.attendanceId,
    this.operatingDay,
    this.clockIn,
    this.clockInDisplay,
    this.clockInEligible = true,
    this.ineligibleReason,
    this.isDefault = false,
    this.overlapping = false,
    this.clockInPreview,
  });

  factory TodayAttendanceItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    final breakJson = json['current_break'];
    final previewJson = json['clock_in_preview'];
    return TodayAttendanceItem(
      scheduleId: json['schedule_id']?.toString(),
      status: json['status']?.toString() ?? 'upcoming',
      scheduledStart: parse(json['scheduled_start']),
      scheduledEnd: parse(json['scheduled_end']),
      scheduledStartDisplay: json['scheduled_start_display']?.toString(),
      scheduledEndDisplay: json['scheduled_end_display']?.toString(),
      currentBreak: breakJson is Map
          ? TodayStaffBreak.fromJson(Map<String, dynamic>.from(breakJson))
          : null,
      attendanceId: json['attendance_id']?.toString(),
      operatingDay: json['operating_day']?.toString(),
      clockIn: parse(json['clock_in']),
      clockInDisplay: json['clock_in_display']?.toString(),
      // 구버전 서버는 이 키를 안 보낸다 → 기존 의미(고를 수 있음) 유지.
      clockInEligible: json.containsKey('clock_in_eligible')
          ? json['clock_in_eligible'] == true
          : true,
      ineligibleReason: json['ineligible_reason']?.toString(),
      isDefault: json['is_default'] == true,
      overlapping: json['overlapping'] == true,
      clockInPreview: previewJson is Map
          ? ClockInPreview.fromJson(Map<String, dynamic>.from(previewJson))
          : null,
    );
  }
}

/// 이전 work_date 미완료(orphan) attendance 1건 — 로그인 경고용 (Issue 11).
class StaleAttendanceItem {
  final String workDate; // ISO date "YYYY-MM-DD"
  final String status;
  final String? clockInDisplay; // store tz "HH:mm"

  const StaleAttendanceItem({
    required this.workDate,
    required this.status,
    this.clockInDisplay,
  });

  factory StaleAttendanceItem.fromJson(Map<String, dynamic> json) {
    return StaleAttendanceItem(
      workDate: json['work_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      clockInDisplay: json['clock_in_display']?.toString(),
    );
  }
}

class IdentifyResponse {
  final String userId;
  final String userName;
  final String? todayStatus;
  final TodayStaffBreak? currentBreak;
  final DateTime? scheduledEnd; // Stage J 서버 응답 확장. 없으면 null (early dialog 분기 skip).

  /// 오늘 모든 attendance (우선순위 정렬). 1건이면 primary 와 동일.
  /// length > 1 이면 client 가 schedule picker 표시 (Issue 8).
  final List<TodayAttendanceItem> todayAttendances;

  /// 선택된 schedule (다중 schedule 시 picker 또는 단일 시 자동). clock action 에 전달.
  /// null 이면 server 가 우선순위로 자동 선택 (Issue 8).
  final String? selectedScheduleId;

  /// 서버가 정한 "앱이 기본으로 다룰 shift" (계약 §1.7). null 이면 워크인 경로.
  /// clock-in 대상이라는 뜻이 아니다 — 진행 중 shift 도 여기 온다.
  final String? defaultScheduleId;

  /// 응답을 만든 서버 시각. **판정용이 아니라 신선도용**이다(계약 §1.2).
  final DateTime? serverTime;

  /// 이전 work_date 미완료(orphan) 기록 (Issue 11). 최신순, 최근 30일.
  /// 있으면 IdentityConfirm 에 경고 배너 표시 (안내만).
  final List<StaleAttendanceItem> staleAttendances;

  const IdentifyResponse({
    required this.userId,
    required this.userName,
    required this.todayStatus,
    this.currentBreak,
    this.scheduledEnd,
    this.todayAttendances = const [],
    this.selectedScheduleId,
    this.defaultScheduleId,
    this.serverTime,
    this.staleAttendances = const [],
  });

  /// 현재 선택된 항목. 선택이 없거나 목록에 없으면 null.
  TodayAttendanceItem? get selectedItem {
    if (selectedScheduleId == null) return null;
    for (final item in todayAttendances) {
      if (item.scheduleId == selectedScheduleId) return item;
    }
    return null;
  }

  /// 선택된 schedule 기준으로 todayStatus/currentBreak/scheduledEnd 를 교체한 복제본.
  /// IdentityConfirmDialog / ActionSheet 는 이 값을 그대로 보므로 위젯 변경 불필요.
  IdentifyResponse withSelectedSchedule(TodayAttendanceItem item) {
    return IdentifyResponse(
      userId: userId,
      userName: userName,
      todayStatus: item.status,
      currentBreak: item.currentBreak,
      scheduledEnd: item.scheduledEnd,
      todayAttendances: todayAttendances,
      selectedScheduleId: item.scheduleId,
      defaultScheduleId: defaultScheduleId,
      serverTime: serverTime,
      staleAttendances: staleAttendances,
    );
  }

  factory IdentifyResponse.fromJson(Map<String, dynamic> json) {
    final breakJson = json['current_break'];
    final endRaw = json['scheduled_end'];
    final attsRaw = json['today_attendances'];
    final serverTimeRaw = json['server_time'];
    return IdentifyResponse(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      todayStatus: json['today_status']?.toString(),
      currentBreak: breakJson is Map
          ? TodayStaffBreak.fromJson(Map<String, dynamic>.from(breakJson))
          : null,
      scheduledEnd: endRaw is String && endRaw.isNotEmpty
          ? DateTime.tryParse(endRaw)
          : null,
      todayAttendances: attsRaw is List
          ? attsRaw
              .whereType<Map>()
              .map((e) =>
                  TodayAttendanceItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      defaultScheduleId: json['default_schedule_id']?.toString(),
      serverTime: serverTimeRaw is String && serverTimeRaw.isNotEmpty
          ? DateTime.tryParse(serverTimeRaw)
          : null,
      staleAttendances: json['stale_attendances'] is List
          ? (json['stale_attendances'] as List)
              .whereType<Map>()
              .map((e) =>
                  StaleAttendanceItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
