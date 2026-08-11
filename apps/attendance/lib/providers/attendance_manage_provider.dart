/// Kiosk 관리자 모드 상태 + 데이터 Provider.
///
/// 매니저 PIN 으로 짧은 admin session 을 열고 그 안에서 오늘 스케줄 / attendance
/// override 를 수행한다. 세션은 in-memory (앱 종료 또는 명시적 로그아웃 시 종료).
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/attendance_device_service.dart';

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

/// 한 attendance 의 break 한 건 (manage UI Breaks 존).
class ManageBreak {
  /// 서버가 준 break 세션 id — Edit Times 가 "이 세션의 시각" 을 지목하는 키.
  /// 구버전 서버 응답엔 없으므로 빈 문자열 fallback (그 경우 편집 대상에서 제외).
  final String id;
  final String type; // paid_10min | unpaid_meal
  final String start; // "HH:mm"
  final String? end; // null = 진행 중

  const ManageBreak({
    this.id = '',
    required this.type,
    required this.start,
    this.end,
  });

  bool get inProgress => end == null;

  /// 시각을 고칠 수 있는 세션인지 — id 가 없으면 지목할 방법이 없다.
  bool get editable => id.isNotEmpty;

  factory ManageBreak.fromJson(Map<String, dynamic> json) => ManageBreak(
        id: json['break_id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        start: json['start']?.toString() ?? '',
        end: json['end']?.toString(),
      );
}

/// 벽시계 ISO(zone 없음) → naive local DateTime. null-safe. toLocal 금지.
DateTime? _tryDt(dynamic v) {
  if (v == null || v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
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
  /// 스케줄에 잡힌 **예정 휴게**. 실제로 찍힌 [breaks] (attendance 세션) 와 다른 것이다.
  /// 둘 다 null = 휴게 없음. 이 값을 읽을 수 있어야 휴게를 옮기거나 지울 수 있다 —
  /// 예전엔 읽지도 못해서 근무창 밖으로 밀려난 휴게를 해소할 방법이 없었다(F6).
  final String? breakStartHHmm;
  final String? breakEndHHmm;
  // 전환기 벽시계 datetime 인코딩 — 있으면 우선(자정 넘김 정확), 없으면 HHmm fallback.
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? breakStartAt;
  final DateTime? breakEndAt;
  final DateTime? operatingDay;
  final String status;
  final String? attendanceId;
  // manage UI 재설계(Issue 10): clock 이벤트 기반 state + anomaly 분리 + breaks 리스트
  final String state; // upcoming | working | breaking | done
  final List<String> anomalies; // late/no_show/early_leave/overtime/no_break
  final List<ManageBreak> breaks;
  // TODO(state-migration): attendanceStatus 는 state/anomalies 로 대체됨. 전환 후 제거.
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
    this.breakStartHHmm,
    this.breakEndHHmm,
    this.startAt,
    this.endAt,
    this.breakStartAt,
    this.breakEndAt,
    this.operatingDay,
    required this.status,
    required this.attendanceId,
    this.state = 'upcoming',
    this.anomalies = const [],
    this.breaks = const [],
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
        breakStartHHmm: json['break_start_time']?.toString(),
        breakEndHHmm: json['break_end_time']?.toString(),
        startAt: _tryDt(json['start_at']),
        endAt: _tryDt(json['end_at']),
        breakStartAt: _tryDt(json['break_start_at']),
        breakEndAt: _tryDt(json['break_end_at']),
        operatingDay: _tryDt(json['operating_day']),
        status: json['status']?.toString() ?? '',
        attendanceId: json['attendance_id']?.toString(),
        state: json['state']?.toString() ?? 'upcoming',
        anomalies: (json['anomalies'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        breaks: (json['breaks'] as List?)
                ?.map((e) => ManageBreak.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        attendanceStatus: json['attendance_status']?.toString(),
        clockInDisplay: json['clock_in_display']?.toString(),
        clockOutDisplay: json['clock_out_display']?.toString(),
      );
}

/// 관리자 모드 세션 상태.
class ManageSessionState {
  final bool active;
  final String? managerUserId;
  final String? managerName;
  final DateTime? expiresAt;
  final String? error;

  /// PIN 메뉴 노출 여부. manage 진입(SV+)보다 PIN 문턱(GM+ 기본)이 높아서,
  /// 세션이 열렸다는 것만으로 Staff PINs 를 보여주면 안 된다.
  final bool canReadPins;
  final bool canUpdatePins;

  /// Store Settings 메뉴 노출 여부. 매장 설정은 console 과 같은 stores:update
  /// 문턱이라, manage 진입(SV+)만으로 열면 안 된다.
  final bool canManageStoreSettings;

  const ManageSessionState({
    this.active = false,
    this.managerUserId,
    this.managerName,
    this.expiresAt,
    this.error,
    this.canReadPins = false,
    this.canUpdatePins = false,
    this.canManageStoreSettings = false,
  });

  ManageSessionState copyWith({
    bool? active,
    String? managerUserId,
    String? managerName,
    DateTime? expiresAt,
    String? error,
    bool? canReadPins,
    bool? canUpdatePins,
    bool? canManageStoreSettings,
    bool clearError = false,
  }) {
    return ManageSessionState(
      active: active ?? this.active,
      managerUserId: managerUserId ?? this.managerUserId,
      managerName: managerName ?? this.managerName,
      expiresAt: expiresAt ?? this.expiresAt,
      error: clearError ? null : (error ?? this.error),
      canReadPins: canReadPins ?? this.canReadPins,
      canUpdatePins: canUpdatePins ?? this.canUpdatePins,
      canManageStoreSettings:
          canManageStoreSettings ?? this.canManageStoreSettings,
    );
  }
}

final attendanceManageSessionProvider =
    StateNotifierProvider<AttendanceManageSessionNotifier, ManageSessionState>(
        (ref) {
  return AttendanceManageSessionNotifier(
    ref.read(attendanceDeviceServiceProvider),
  );
});

class AttendanceManageSessionNotifier extends StateNotifier<ManageSessionState> {
  final AttendanceDeviceService _service;

  AttendanceManageSessionNotifier(this._service)
      : super(const ManageSessionState());

  Future<bool> openWithPin({required String pin}) async {
    state = state.copyWith(clearError: true);
    try {
      final body = await _service.openManageSession(pin: pin);
      state = ManageSessionState(
        active: true,
        managerUserId: body['manager_user_id']?.toString(),
        managerName: body['manager_name']?.toString(),
        expiresAt: DateTime.tryParse(body['expires_at']?.toString() ?? ''),
        canReadPins: body['can_read_pins'] == true,
        canUpdatePins: body['can_update_pins'] == true,
        canManageStoreSettings: body['can_manage_store_settings'] == true,
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
    await _service.closeManageSession();
    state = const ManageSessionState();
  }

  /// 401/403 발생 시 외부에서 강제 무효화.
  void invalidate({String? error}) {
    _service.setManageToken(null);
    state = ManageSessionState(error: error);
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
