/// PIN 식별 응답 모델 — POST /attendance/identify-by-pin.
///
/// Phase 3 server 응답: user_id, user_name, today_status.
/// Phase 5 확장 예정 (Stage J): current_break (on_break 일 때 break 종류/시작 시각).
/// mockup 에선 on_break 시 break info 표시. server 미지원이면 nullable 유지.

import '../providers/attendance_dashboard_provider.dart';

class IdentifyResponse {
  final String userId;
  final String userName;
  final String? todayStatus;
  final TodayStaffBreak? currentBreak;
  final DateTime? scheduledEnd; // Stage J 서버 응답 확장. 없으면 null (early dialog 분기 skip).

  const IdentifyResponse({
    required this.userId,
    required this.userName,
    required this.todayStatus,
    this.currentBreak,
    this.scheduledEnd,
  });

  factory IdentifyResponse.fromJson(Map<String, dynamic> json) {
    final breakJson = json['current_break'];
    final endRaw = json['scheduled_end'];
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
    );
  }
}
