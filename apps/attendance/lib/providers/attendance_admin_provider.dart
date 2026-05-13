/// Kiosk 관리자 모드 상태 + 데이터 Provider.
///
/// 매니저 PIN 으로 짧은 admin session 을 열고 그 안에서 오늘 스케줄 / attendance
/// override 를 수행한다. 세션은 in-memory (앱 종료 또는 명시적 로그아웃 시 종료).
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/attendance_device_service.dart';

class AdminManager {
  final String userId;
  final String fullName;
  final String roleName;
  final int rolePriority;

  const AdminManager({
    required this.userId,
    required this.fullName,
    required this.roleName,
    required this.rolePriority,
  });

  factory AdminManager.fromJson(Map<String, dynamic> json) => AdminManager(
        userId: json['user_id']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        roleName: json['role_name']?.toString() ?? '',
        rolePriority: (json['role_priority'] as num?)?.toInt() ?? 99,
      );
}

class AdminAssignableUser {
  final String userId;
  final String fullName;
  final String roleName;

  const AdminAssignableUser({
    required this.userId,
    required this.fullName,
    required this.roleName,
  });

  factory AdminAssignableUser.fromJson(Map<String, dynamic> json) =>
      AdminAssignableUser(
        userId: json['user_id']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        roleName: json['role_name']?.toString() ?? '',
      );
}

class AdminWorkRole {
  final String workRoleId;
  final String? name;
  final String? shiftName;
  final String? positionName;
  final String? defaultStartHHmm;
  final String? defaultEndHHmm;

  const AdminWorkRole({
    required this.workRoleId,
    required this.name,
    required this.shiftName,
    required this.positionName,
    required this.defaultStartHHmm,
    required this.defaultEndHHmm,
  });

  /// 표시용 라벨 — "{shift} · {position}" 우선, 없으면 work role 자체 이름.
  /// work_roles 테이블은 (store, shift, position) 조합으로 유니크하므로
  /// 사용자가 운영 컨텍스트에서 식별할 수 있도록 두 값을 모두 표시.
  String get displayLabel {
    final s = shiftName?.trim();
    final p = positionName?.trim();
    if (s != null && s.isNotEmpty && p != null && p.isNotEmpty) {
      return '$s · $p';
    }
    if (p != null && p.isNotEmpty) return p;
    if (s != null && s.isNotEmpty) return s;
    if (name != null && name!.isNotEmpty) return name!;
    return workRoleId;
  }

  factory AdminWorkRole.fromJson(Map<String, dynamic> json) => AdminWorkRole(
        workRoleId: json['work_role_id']?.toString() ?? '',
        name: json['name']?.toString(),
        shiftName: json['shift_name']?.toString(),
        positionName: json['position_name']?.toString(),
        defaultStartHHmm: json['default_start_time']?.toString(),
        defaultEndHHmm: json['default_end_time']?.toString(),
      );
}

class AdminScheduleRow {
  final String scheduleId;
  final String userId;
  final String userName;
  final String? workRoleId;
  final String? workRoleName;
  final String? shiftName;
  final String? positionName;
  final String? startHHmm;
  final String? endHHmm;
  final String status;
  final String? attendanceId;
  final String? attendanceStatus;
  final String? clockInDisplay;
  final String? clockOutDisplay;

  const AdminScheduleRow({
    required this.scheduleId,
    required this.userId,
    required this.userName,
    required this.workRoleId,
    required this.workRoleName,
    required this.shiftName,
    required this.positionName,
    required this.startHHmm,
    required this.endHHmm,
    required this.status,
    required this.attendanceId,
    required this.attendanceStatus,
    required this.clockInDisplay,
    required this.clockOutDisplay,
  });

  /// "Shift · Position" 또는 단일 — work role 식별 라벨.
  String? get workRoleLabel {
    final s = shiftName?.trim();
    final p = positionName?.trim();
    if (s != null && s.isNotEmpty && p != null && p.isNotEmpty) {
      return '$s · $p';
    }
    if (p != null && p.isNotEmpty) return p;
    if (s != null && s.isNotEmpty) return s;
    if (workRoleName != null && workRoleName!.isNotEmpty) return workRoleName;
    return null;
  }

  factory AdminScheduleRow.fromJson(Map<String, dynamic> json) =>
      AdminScheduleRow(
        scheduleId: json['schedule_id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        userName: json['user_name']?.toString() ?? '',
        workRoleId: json['work_role_id']?.toString(),
        workRoleName: json['work_role_name']?.toString(),
        shiftName: json['shift_name']?.toString(),
        positionName: json['position_name']?.toString(),
        startHHmm: json['start_time']?.toString(),
        endHHmm: json['end_time']?.toString(),
        status: json['status']?.toString() ?? '',
        attendanceId: json['attendance_id']?.toString(),
        attendanceStatus: json['attendance_status']?.toString(),
        clockInDisplay: json['clock_in_display']?.toString(),
        clockOutDisplay: json['clock_out_display']?.toString(),
      );
}

/// 관리자 모드 세션 상태.
class AdminSessionState {
  final bool active;
  final String? managerUserId;
  final String? managerName;
  final DateTime? expiresAt;
  final String? error;

  const AdminSessionState({
    this.active = false,
    this.managerUserId,
    this.managerName,
    this.expiresAt,
    this.error,
  });

  AdminSessionState copyWith({
    bool? active,
    String? managerUserId,
    String? managerName,
    DateTime? expiresAt,
    String? error,
    bool clearError = false,
  }) {
    return AdminSessionState(
      active: active ?? this.active,
      managerUserId: managerUserId ?? this.managerUserId,
      managerName: managerName ?? this.managerName,
      expiresAt: expiresAt ?? this.expiresAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final attendanceAdminSessionProvider =
    StateNotifierProvider<AttendanceAdminSessionNotifier, AdminSessionState>(
        (ref) {
  return AttendanceAdminSessionNotifier(
    ref.read(attendanceDeviceServiceProvider),
  );
});

class AttendanceAdminSessionNotifier extends StateNotifier<AdminSessionState> {
  final AttendanceDeviceService _service;

  AttendanceAdminSessionNotifier(this._service)
      : super(const AdminSessionState());

  Future<bool> openWithPin({required String userId, required String pin}) async {
    state = state.copyWith(clearError: true);
    try {
      final body = await _service.openAdminSession(userId: userId, pin: pin);
      state = AdminSessionState(
        active: true,
        managerUserId: body['manager_user_id']?.toString(),
        managerName: body['manager_name']?.toString(),
        expiresAt: DateTime.tryParse(body['expires_at']?.toString() ?? ''),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _parseError(e, 'Verification failed'));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Verification failed');
      return false;
    }
  }

  Future<void> close() async {
    await _service.closeAdminSession();
    state = const AdminSessionState();
  }

  /// 401/403 발생 시 외부에서 강제 무효화.
  void invalidate({String? error}) {
    _service.setAdminToken(null);
    state = AdminSessionState(error: error);
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
