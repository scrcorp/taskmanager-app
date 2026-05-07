/// Attendance 대시보드용 데이터 Provider (today-staff + notices)
///
/// 60초 주기로 폴링하며 매장 근무자 상태와 공지를 가져온다.
/// `AttendanceDeviceService.getTodayStaff` / `getNotices` 를 사용.
///
/// 기기 토큰이 없거나 매장 미할당 상태에서도 실패하지 않도록 에러는 state.error 로
/// 보관. UI 는 리스트가 비어있거나 에러가 있으면 placeholder 를 보여준다.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/attendance_device_service.dart';

/// 현재 진행 중인 break 요약
class TodayStaffBreak {
  final DateTime startedAt;
  final String breakType; // 'paid_short' | 'unpaid_long'

  const TodayStaffBreak({required this.startedAt, required this.breakType});

  static TodayStaffBreak? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final startedRaw = json['started_at']?.toString();
    if (startedRaw == null || startedRaw.isEmpty) return null;
    final started = DateTime.tryParse(startedRaw);
    if (started == null) return null;
    return TodayStaffBreak(
      startedAt: started,
      breakType: json['break_type']?.toString() ?? '',
    );
  }
}

/// today-staff 응답 1건
class TodayStaffRow {
  final String userId;
  final String userName;
  final String? scheduleId;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? scheduledStartDisplay; // store tz 기준 HH:mm (서버 포매팅)
  final String? scheduledEndDisplay;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? clockInDisplay;
  final String? clockOutDisplay;
  final String status; // upcoming | soon | working | on_break | late | clocked_out | no_show | cancelled
  final TodayStaffBreak? currentBreak;
  final int paidBreakMinutes;
  final int unpaidBreakMinutes;

  const TodayStaffRow({
    required this.userId,
    required this.userName,
    required this.scheduleId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.scheduledStartDisplay,
    required this.scheduledEndDisplay,
    required this.clockIn,
    required this.clockOut,
    required this.clockInDisplay,
    required this.clockOutDisplay,
    required this.status,
    required this.currentBreak,
    required this.paidBreakMinutes,
    required this.unpaidBreakMinutes,
  });

  factory TodayStaffRow.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return TodayStaffRow(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString(),
      scheduledStart: parse(json['scheduled_start']),
      scheduledEnd: parse(json['scheduled_end']),
      scheduledStartDisplay: json['scheduled_start_display']?.toString(),
      scheduledEndDisplay: json['scheduled_end_display']?.toString(),
      clockIn: parse(json['clock_in']),
      clockOut: parse(json['clock_out']),
      clockInDisplay: json['clock_in_display']?.toString(),
      clockOutDisplay: json['clock_out_display']?.toString(),
      status: json['status']?.toString() ?? 'upcoming',
      currentBreak: TodayStaffBreak.fromJson(
        json['current_break'] is Map
            ? Map<String, dynamic>.from(json['current_break'] as Map)
            : null,
      ),
      paidBreakMinutes: (json['paid_break_minutes'] as num?)?.toInt() ?? 0,
      unpaidBreakMinutes: (json['unpaid_break_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 공지 1건
class AttendanceNotice {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;

  const AttendanceNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory AttendanceNotice.fromJson(Map<String, dynamic> json) {
    return AttendanceNotice(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// 대시보드 state
class AttendanceDashboardState {
  final bool loading;
  final List<TodayStaffRow> staff;
  final List<AttendanceNotice> notices;
  final String? error;
  final DateTime? lastRefreshedAt;

  const AttendanceDashboardState({
    this.loading = false,
    this.staff = const [],
    this.notices = const [],
    this.error,
    this.lastRefreshedAt,
  });

  AttendanceDashboardState copyWith({
    bool? loading,
    List<TodayStaffRow>? staff,
    List<AttendanceNotice>? notices,
    String? error,
    DateTime? lastRefreshedAt,
    bool clearError = false,
  }) {
    return AttendanceDashboardState(
      loading: loading ?? this.loading,
      staff: staff ?? this.staff,
      notices: notices ?? this.notices,
      error: clearError ? null : (error ?? this.error),
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }
}

/// Dashboard data Provider (today-staff + notices, 60s 폴링)
final attendanceDashboardProvider = StateNotifierProvider<
    AttendanceDashboardNotifier, AttendanceDashboardState>((ref) {
  final notifier = AttendanceDashboardNotifier(
    ref.read(attendanceDeviceServiceProvider),
  );
  ref.onDispose(notifier.stopPolling);
  return notifier;
});

class AttendanceDashboardNotifier
    extends StateNotifier<AttendanceDashboardState> {
  final AttendanceDeviceService _service;
  Timer? _pollTimer;

  AttendanceDashboardNotifier(this._service)
      : super(const AttendanceDashboardState());

  /// 초기 로드 + 60초 주기 폴링 시작
  void startPolling({Duration interval = const Duration(seconds: 60)}) {
    stopPolling();
    // 즉시 한 번 수행
    refresh();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 수동 refresh — 두 API 병렬 호출
  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _service.getTodayStaff(),
        _service.getNotices(limit: 10),
      ]);
      final staffJson = results[0];
      final noticesJson = results[1];
      state = state.copyWith(
        loading: false,
        staff: staffJson.map(TodayStaffRow.fromJson).toList(),
        notices: noticesJson.map(AttendanceNotice.fromJson).toList(),
        lastRefreshedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: _parseError(e, 'Failed to load dashboard data.'),
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load dashboard data.',
      );
    }
  }

  String _parseError(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map<String, dynamic>) {
      final data = e.response!.data as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return fallback;
  }
}
