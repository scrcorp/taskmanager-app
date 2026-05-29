/// PIN 식별 응답 모델 — POST /attendance/identify-by-pin.
///
/// Phase 3: user_id, user_name, today_status.
/// Stage J: current_break, scheduled_end.
/// Issue 8: today_attendances — 한 직원의 오늘 모든 schedule. 2+ 건이면 picker.

import '../providers/attendance_dashboard_provider.dart';

/// 오늘 attendance(=schedule) 1건 — 다중 schedule picker 용 (Issue 8).
class TodayAttendanceItem {
  final String? scheduleId;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? scheduledStartDisplay;
  final String? scheduledEndDisplay;
  final TodayStaffBreak? currentBreak;

  const TodayAttendanceItem({
    required this.scheduleId,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledStartDisplay,
    this.scheduledEndDisplay,
    this.currentBreak,
  });

  factory TodayAttendanceItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    final breakJson = json['current_break'];
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
    this.staleAttendances = const [],
  });

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
      staleAttendances: staleAttendances,
    );
  }

  factory IdentifyResponse.fromJson(Map<String, dynamic> json) {
    final breakJson = json['current_break'];
    final endRaw = json['scheduled_end'];
    final attsRaw = json['today_attendances'];
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
