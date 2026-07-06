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
import 'attendance_manage_provider.dart' show ManageBreak;

/// 현재 진행 중인 break 요약
class TodayStaffBreak {
  final DateTime startedAt;
  final String breakType; // 'paid_10min' | 'unpaid_meal' (구: 'paid_short' | 'unpaid_long')

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
  // manage 와 공용 — clock 이벤트 기반 state + anomaly + 전체 break (UI 통합용)
  final String state; // upcoming | working | breaking | done
  final List<String> anomalies;
  final List<ManageBreak> breaks;
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
    this.state = 'upcoming',
    this.anomalies = const [],
    this.breaks = const [],
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
      state: json['state']?.toString() ?? 'upcoming',
      anomalies: (json['anomalies'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      breaks: (json['breaks'] as List?)
              ?.map((e) => ManageBreak.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      currentBreak: TodayStaffBreak.fromJson(
        json['current_break'] is Map
            ? Map<String, dynamic>.from(json['current_break'] as Map)
            : null,
      ),
      paidBreakMinutes: (json['paid_break_minutes'] as num?)?.toInt() ?? 0,
      unpaidBreakMinutes: (json['unpaid_break_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  /// build_response (clock action 응답) → TodayStaffRow patch.
  ///
  /// today-staff row 와 schema 가 살짝 다름:
  /// - status 는 server 의 `effective_status` 필드 사용 (DB raw status 아님,
  ///   'late' → 'working' 승격된 값)
  /// - current_break: build_response 의 breaks 배열 중 ended_at IS NULL 인 것을 추출
  factory TodayStaffRow.fromClockResponse(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    TodayStaffBreak? current;
    final breaks = json['breaks'];
    if (breaks is List) {
      for (final br in breaks) {
        if (br is Map && br['ended_at'] == null) {
          final started = parse(br['started_at']);
          if (started != null) {
            current = TodayStaffBreak(
              startedAt: started,
              breakType: br['break_type']?.toString() ?? '',
            );
            break;
          }
        }
      }
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
      status: (json['effective_status'] ?? json['status'] ?? 'upcoming').toString(),
      // 낙관적 패치 — state 는 clock 이벤트로 derive (다음 폴링이 anomalies/breaks 채움)
      state: parse(json['clock_out']) != null
          ? 'done'
          : parse(json['clock_in']) != null
              ? (current != null ? 'breaking' : 'working')
              : 'upcoming',
      currentBreak: current,
      paidBreakMinutes: (json['paid_break_minutes'] as num?)?.toInt() ?? 0,
      unpaidBreakMinutes: (json['unpaid_break_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 대시보드 state (today-staff)
class AttendanceDashboardState {
  final bool loading;
  final List<TodayStaffRow> staff;
  final String? error;
  final DateTime? lastRefreshedAt;
  /// today-staff 응답의 마지막 ETag — 다음 refresh() 의 If-None-Match 로 재사용
  /// (Task 3: 304 시 body 전송 생략해 polling 전송량 절감).
  final String? etag;

  const AttendanceDashboardState({
    this.loading = false,
    this.staff = const [],
    this.error,
    this.lastRefreshedAt,
    this.etag,
  });

  AttendanceDashboardState copyWith({
    bool? loading,
    List<TodayStaffRow>? staff,
    String? error,
    DateTime? lastRefreshedAt,
    String? etag,
    bool clearError = false,
  }) {
    return AttendanceDashboardState(
      loading: loading ?? this.loading,
      staff: staff ?? this.staff,
      error: clearError ? null : (error ?? this.error),
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      etag: etag ?? this.etag,
    );
  }
}

/// Dashboard data Provider (today-staff, 60s 폴링)
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

  /// 수동 refresh — today-staff 1 API.
  ///
  /// Task 3: If-None-Match 로 마지막 ETag 를 보내 변경 없으면 304(빈 바디) 를
  /// 받는다 — 이 경우 staff 리스트는 그대로 두고 loading/lastRefreshedAt 만
  /// 갱신한다 (기존 데이터를 절대 덮어쓰지 않음).
  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _service.getTodayStaff(ifNoneMatch: state.etag);
      if (result.notModified) {
        state = state.copyWith(
          loading: false,
          etag: result.etag,
          lastRefreshedAt: DateTime.now(),
        );
        return;
      }
      state = state.copyWith(
        loading: false,
        staff: result.data.map(TodayStaffRow.fromJson).toList(),
        etag: result.etag,
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

  /// 해당 user 의 row 를 응답 row 로 교체 (refresh 호출 없이 즉시 반영).
  ///
  /// Issue 3 트랙 A: clock action 응답을 그대로 활용해 dashboard state 만 patch.
  /// 폴링/refresh 호출 없음 — 폴링은 multi-device sync backstop 으로만 유지.
  /// row.userId 가 staff list 에 없으면 무시 (안전망 — 다음 polling tick 에 들어옴).
  void patchStaffByUserId(TodayStaffRow row) {
    final idx = state.staff.indexWhere((r) => r.userId == row.userId);
    if (idx < 0) return;
    final next = List<TodayStaffRow>.of(state.staff);
    next[idx] = row;
    state = state.copyWith(staff: next);
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
