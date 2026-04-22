/// Clock In/Out 상태 관리 Provider
///
/// 키오스크(패드)에서 현재 근무 중인 직원, 예정 직원을 관리.
/// 매장은 빌드 시 --dart-define=KIOSK_STORE_ID / KIOSK_STORE_NAME 으로 고정.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../services/clock_service.dart';

/// 근무 중인 직원 정보
class OnShiftEmployee {
  final String id;
  final String name;
  final String role;
  final String since;
  final String? status; // 'working', 'break'

  const OnShiftEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.since,
    this.status,
  });

  factory OnShiftEmployee.fromJson(Map<String, dynamic> json) {
    return OnShiftEmployee(
      id: json['id'] ?? json['user_id'] ?? '',
      name: json['name'] ?? json['user_name'] ?? '',
      role: json['role'] ?? json['work_role_name'] ?? '',
      since: json['since'] ?? json['start_time'] ?? '',
      status: json['status'],
    );
  }
}

/// 다음 근무 예정자 정보
class ComingUpEmployee {
  final String id;
  final String name;
  final String role;
  final String startTime;
  final String endTime;

  const ComingUpEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.startTime,
    required this.endTime,
  });

  factory ComingUpEmployee.fromJson(Map<String, dynamic> json) {
    return ComingUpEmployee(
      id: json['id'] ?? json['user_id'] ?? '',
      name: json['name'] ?? json['user_name'] ?? '',
      role: json['role'] ?? json['work_role_name'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
    );
  }
}

/// 근태 요약 (모바일용)
class AttendanceSummary {
  final int daysWorked;
  final int lateCount;
  final int earlyLeaveCount;
  final int totalScheduled;
  final String month;

  const AttendanceSummary({
    this.daysWorked = 0,
    this.lateCount = 0,
    this.earlyLeaveCount = 0,
    this.totalScheduled = 0,
    this.month = '',
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      daysWorked: json['days_worked'] ?? 0,
      lateCount: json['late_count'] ?? 0,
      earlyLeaveCount: json['early_leave_count'] ?? 0,
      totalScheduled: json['total_scheduled'] ?? 0,
      month: json['month'] ?? '',
    );
  }
}

/// 오늘 동료 정보 (모바일용)
class TeamMember {
  final String id;
  final String name;
  final String role;
  final String shift; // 'AM', 'PM' 등

  const TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.shift,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] ?? json['user_id'] ?? '',
      name: json['name'] ?? json['user_name'] ?? '',
      role: json['role'] ?? json['work_role_name'] ?? '',
      shift: json['shift'] ?? json['shift_name'] ?? '',
    );
  }
}

/// Clock 화면 전체 상태
class ClockState {
  // 태블릿(키오스크)용
  final List<OnShiftEmployee> onShift;
  final List<ComingUpEmployee> comingUp;
  // 모바일용
  final AttendanceSummary? attendance;
  final List<TeamMember> todayTeam;
  // 공통
  final bool isLoading;
  final String? error;

  const ClockState({
    this.onShift = const [],
    this.comingUp = const [],
    this.attendance,
    this.todayTeam = const [],
    this.isLoading = false,
    this.error,
  });

  /// 빌드 시 고정된 매장 ID
  String? get storeId =>
      AppConstants.kioskStoreId.isNotEmpty ? AppConstants.kioskStoreId : null;

  /// 빌드 시 고정된 매장 이름
  String get storeName =>
      AppConstants.kioskStoreName.isNotEmpty ? AppConstants.kioskStoreName : 'Store';

  ClockState copyWith({
    List<OnShiftEmployee>? onShift,
    List<ComingUpEmployee>? comingUp,
    AttendanceSummary? attendance,
    List<TeamMember>? todayTeam,
    bool? isLoading,
    String? error,
  }) {
    return ClockState(
      onShift: onShift ?? this.onShift,
      comingUp: comingUp ?? this.comingUp,
      attendance: attendance ?? this.attendance,
      todayTeam: todayTeam ?? this.todayTeam,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Clock 상태 Provider
final clockProvider = StateNotifierProvider<ClockNotifier, ClockState>((ref) {
  return ClockNotifier(ref.read(clockServiceProvider));
});

class ClockNotifier extends StateNotifier<ClockState> {
  final ClockService _service;

  ClockNotifier(this._service) : super(const ClockState());

  /// 현재 근무 중 + 예정자 목록 로드
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final storeId = state.storeId;
      final results = await Future.wait([
        _service.getOnShift(storeId: storeId),
        _service.getComingUp(storeId: storeId),
      ]);
      state = state.copyWith(
        isLoading: false,
        onShift: (results[0])
            .map((e) => OnShiftEmployee.fromJson(e as Map<String, dynamic>))
            .toList(),
        comingUp: (results[1])
            .map((e) => ComingUpEmployee.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 모바일용: 근태 요약 + 오늘 팀 로드
  Future<void> loadMobileData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _service.getAttendanceSummary(),
        _service.getTodayTeam(),
      ]);
      state = state.copyWith(
        isLoading: false,
        attendance: AttendanceSummary.fromJson(results[0] as Map<String, dynamic>),
        todayTeam: (results[1] as List)
            .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clock In 처리
  Future<Map<String, dynamic>?> clockIn(String pin) async {
    try {
      final result = await _service.clockIn(pin, storeId: state.storeId);
      await loadDashboard();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Clock Out 처리
  Future<Map<String, dynamic>?> clockOut(String pin) async {
    try {
      final result = await _service.clockOut(pin, storeId: state.storeId);
      await loadDashboard();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Break 토글
  Future<Map<String, dynamic>?> toggleBreak(String pin) async {
    try {
      final result = await _service.toggleBreak(pin, storeId: state.storeId);
      await loadDashboard();
      return result;
    } catch (_) {
      return null;
    }
  }
}
