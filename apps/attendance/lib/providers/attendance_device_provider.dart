/// 태블릿 기기(device) 상태 관리 Provider
///
/// `/attendance-temp` shell의 flow를 관리:
/// 1. 토큰 없음          → AttendanceDeviceStatus.needsRegister
/// 2. 토큰 있고 me 성공  → needsStore (store_id null) 또는 ready
/// 3. 토큰 있고 401      → 토큰 삭제 후 needsRegister
///
/// Actions: register, assignStore, unregister, clockAction, refresh.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/identify_response.dart';
import '../models/tip_models.dart';
import '../services/attendance_device_service.dart';
import '../utils/attendance_device_storage.dart';
import 'package:htm_core/htm_core.dart';

/// 기기 상태 phase
enum AttendanceDeviceStatus {
  /// 초기 로딩 (checkStatus 실행 전)
  initial,

  /// me 호출 중
  loading,

  /// 토큰 없음 → access code 화면
  needsRegister,

  /// 토큰 유효하나 매장 미할당 → store select 화면
  needsStore,

  /// 토큰 유효 + 매장 설정됨 → main clockin 화면
  ready,
}

/// 기기 정보 (서버 DeviceMeResponse에 대응)
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String organizationId;
  final String? storeId;
  final String? storeName;
  final String? storeTimezone;   // IANA tz, e.g. "America/Los_Angeles"
  final int? storeTimezoneOffsetMinutes;  // 현재 UTC 오프셋 (분, 예: PDT=-420)
  final String? workDate;        // store tz + day_start 기준 "YYYY-MM-DD"
  final DateTime? registeredAt;
  final DateTime? lastSeenAt;
  /// 매장의 워크인 허용 여부 — Settings Registry `attendance.walk_in_allowed` 해소값.
  /// 없으면 기본 false (스케줄 없이 출근 불가).
  final bool walkInAllowed;

  /// clock-out 시 tip 입력 화면 노출 여부 — `attendance.tip_entry_enabled` 해소값.
  /// store 설정이라 같은 매장의 모든 기기가 같은 값을 본다. 없으면 기본 false.
  final bool tipEntryEnabled;

  /// 신규 스케줄 기본 길이(분) — `work.default_schedule_duration_minutes` 해소값(D8-2).
  ///
  /// 매장마다 다른 값이라 앱이 숫자를 들고 있으면 안 된다. 서버가 매장 설정을
  /// org/store 로 해소해 내려주고, 설정이 없으면 서버 기본(330)을 내려준다.
  /// 응답에 이 필드가 없으면(구버전 서버) 앱 폴백 [fallbackShiftMinutes] 로 떨어진다.
  final int? defaultScheduleDurationMinutes;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.organizationId,
    this.storeId,
    this.storeName,
    this.storeTimezone,
    this.storeTimezoneOffsetMinutes,
    this.workDate,
    this.registeredAt,
    this.lastSeenAt,
    this.walkInAllowed = false,
    this.tipEntryEnabled = false,
    this.defaultScheduleDurationMinutes,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    return DeviceInfo(
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? 'Device',
      organizationId: json['organization_id']?.toString() ?? '',
      storeId: json['store_id']?.toString(),
      storeName: json['store_name']?.toString(),
      storeTimezone: json['store_timezone']?.toString(),
      storeTimezoneOffsetMinutes:
          (json['store_timezone_offset_minutes'] as num?)?.toInt(),
      workDate: json['work_date']?.toString(),
      registeredAt: parseDt(json['registered_at']),
      lastSeenAt: parseDt(json['last_seen_at']),
      walkInAllowed: json['walk_in_allowed'] == true,
      tipEntryEnabled: json['tip_entry_enabled'] == true,
      // 0 이하는 값이 아니라 잘못된 설정이다 — 폴백이 걸리도록 null 로 떨어뜨린다.
      defaultScheduleDurationMinutes: () {
        final v = (json['default_schedule_duration_minutes'] as num?)?.toInt();
        return (v == null || v <= 0) ? null : v;
      }(),
    );
  }
}

/// 기기 상태 데이터
class AttendanceDeviceState {
  final AttendanceDeviceStatus status;
  final DeviceInfo? device;
  final String? error;

  const AttendanceDeviceState({
    this.status = AttendanceDeviceStatus.initial,
    this.device,
    this.error,
  });

  AttendanceDeviceState copyWith({
    AttendanceDeviceStatus? status,
    DeviceInfo? device,
    String? error,
    bool clearDevice = false,
    bool clearError = false,
  }) {
    return AttendanceDeviceState(
      status: status ?? this.status,
      device: clearDevice ? null : (device ?? this.device),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 기기 상태 Provider
final attendanceDeviceProvider =
    StateNotifierProvider<AttendanceDeviceNotifier, AttendanceDeviceState>((ref) {
  return AttendanceDeviceNotifier(ref.read(attendanceDeviceServiceProvider));
});

/// 기기 상태 Notifier
class AttendanceDeviceNotifier extends StateNotifier<AttendanceDeviceState> {
  final AttendanceDeviceService _service;

  AttendanceDeviceNotifier(this._service) : super(const AttendanceDeviceState());

  /// 시작 시 호출: 저장된 토큰을 확인하고 me()로 유효성 검증
  Future<void> checkStatus() async {
    state = state.copyWith(status: AttendanceDeviceStatus.loading, clearError: true);
    final token = await AttendanceDeviceStorage.getToken();
    if (token == null || token.isEmpty) {
      state = const AttendanceDeviceState(status: AttendanceDeviceStatus.needsRegister);
      return;
    }
    try {
      final data = await _service.getMe();
      final device = DeviceInfo.fromJson(data);
      state = AttendanceDeviceState(
        status: device.storeId == null || device.storeId!.isEmpty
            ? AttendanceDeviceStatus.needsStore
            : AttendanceDeviceStatus.ready,
        device: device,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // 토큰 무효 → 제거 + access code 화면
        await AttendanceDeviceStorage.clearToken();
        state = const AttendanceDeviceState(status: AttendanceDeviceStatus.needsRegister);
      } else {
        state = AttendanceDeviceState(
          status: AttendanceDeviceStatus.needsRegister,
          error: _parseError(e, 'Failed to verify device. Please register again.'),
        );
      }
    } catch (e) {
      state = AttendanceDeviceState(
        status: AttendanceDeviceStatus.needsRegister,
        error: 'Failed to verify device. Please register again.',
      );
    }
  }

  /// Access code 등록
  ///
  /// 성공 시 token 저장 + me 호출하여 storeId 확인 후 적절한 상태로 전환.
  Future<bool> register(String accessCode) async {
    state = state.copyWith(status: AttendanceDeviceStatus.loading, clearError: true);
    try {
      final fingerprint = await _ensureFingerprint();
      final data = await _service.register(
        accessCode: accessCode,
        fingerprint: fingerprint,
      );
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        state = state.copyWith(
          status: AttendanceDeviceStatus.needsRegister,
          error: 'Server did not return a device token.',
        );
        return false;
      }
      await AttendanceDeviceStorage.setToken(token);
      await AttendanceDeviceStorage.setAccessCode(accessCode);
      // 재등록 = 키오스크 의도 켜기 + 잠금 즉시 시작
      await KioskIntent.setEnabled(true);
      if (!await KioskLock.isLocked()) {
        await KioskLock.start();
      }
      // register 응답이 store_id를 포함할 수 있지만 me를 한 번 더 호출해 일관된 상태 구성
      final meData = await _service.getMe();
      final device = DeviceInfo.fromJson(meData);
      state = AttendanceDeviceState(
        status: device.storeId == null || device.storeId!.isEmpty
            ? AttendanceDeviceStatus.needsStore
            : AttendanceDeviceStatus.ready,
        device: device,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        status: AttendanceDeviceStatus.needsRegister,
        error: _parseError(e, 'Invalid access code.'),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AttendanceDeviceStatus.needsRegister,
        error: 'Failed to register device.',
      );
      return false;
    }
  }

  /// 매장 할당/변경
  Future<bool> assignStore(String storeId) async {
    try {
      final data = await _service.setStore(storeId);
      final device = DeviceInfo.fromJson(data);
      state = AttendanceDeviceState(
        status: device.storeId == null || device.storeId!.isEmpty
            ? AttendanceDeviceStatus.needsStore
            : AttendanceDeviceStatus.ready,
        device: device,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await AttendanceDeviceStorage.clearToken();
        state = const AttendanceDeviceState(
          status: AttendanceDeviceStatus.needsRegister,
          error: 'Device session expired. Please register again.',
        );
      } else {
        state = state.copyWith(error: _parseError(e, 'Failed to assign store.'));
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to assign store.');
      return false;
    }
  }

  /// 기기 해제 (DELETE /me + 로컬 토큰 삭제)
  Future<void> unregister() async {
    try {
      await _service.unregister();
    } catch (_) {
      // 서버 호출 실패해도 로컬 토큰은 반드시 삭제
    }
    // 키오스크 잠금이 걸려있으면 같이 해제 — unregister 후 잠금 잔존 방지
    await KioskIntent.setEnabled(false);
    if (await KioskLock.isLocked()) {
      await KioskLock.stop();
    }
    await AttendanceDeviceStorage.clearToken();
    await AttendanceDeviceStorage.clearAccessCode();
    state = const AttendanceDeviceState(status: AttendanceDeviceStatus.needsRegister);
  }

  /// 매장 변경을 위해 status를 needsStore로 이동 (토큰은 유지)
  void requestChangeStore() {
    state = state.copyWith(status: AttendanceDeviceStatus.needsStore, clearError: true);
  }

  /// Polling 등 백그라운드에서 device.work_date / store tz offset 을 새로 받아온다.
  /// 키오스크가 켜져있는 동안 자정/business-day 경계에서 헤더가 즉시 갱신되도록 사용.
  /// state.status 는 그대로 유지하며 device 만 교체. 401 도 흔들지 않음 — 다른
  /// 인터셉터/타이머가 처리.
  Future<void> softRefreshDevice() async {
    if (state.status != AttendanceDeviceStatus.ready) return;
    try {
      final data = await _service.getMe();
      final device = DeviceInfo.fromJson(data);
      state = state.copyWith(device: device);
    } catch (_) {
      // 일시 네트워크 오류는 무시 — 다음 polling tick 에서 다시 시도.
    }
  }

  /// Clock 액션 (clock-in / clock-out / break-start / break-end)
  ///
  /// [action] — 'clock-in' | 'clock-out' | 'break-start' | 'break-end'
  /// [userId] — 대시보드에서 선택된 직원 ID
  /// [pin] — 6자리 숫자
  /// [breakType] — break-start 에만 사용 ('paid_10min' | 'unpaid_meal')
  /// [walkIn] — true 이면 스케줄 없는 워크인 클락인 (body 에 walk_in=true 포함)
  /// 반환: { success: bool, message: String, data: Map? }
  Future<ClockActionResult> performClockAction({
    required String action,
    required String userId,
    required String pin,
    String? breakType,
    String? reason,
    String? scheduleId,
    bool walkIn = false,
  }) async {
    try {
      Map<String, dynamic> result;
      switch (action) {
        case 'clock-in':
          result = await _service.clockIn(
            userId: userId,
            pin: pin,
            scheduleId: scheduleId,
            walkIn: walkIn,
            reason: reason,
          );
          break;
        case 'clock-out':
          result = await _service.clockOut(userId: userId, pin: pin, reason: reason);
          break;
        case 'break-start':
          if (breakType == null || breakType.isEmpty) {
            return const ClockActionResult(
              success: false,
              message: 'Break type is required',
            );
          }
          result = await _service.breakStart(
            userId: userId,
            pin: pin,
            breakType: breakType,
          );
          break;
        case 'break-end':
          // break 초과 사유 — unpaid_meal 35분 이상이면 서버가 필수로 요구한다.
          result = await _service.breakEnd(userId: userId, pin: pin, reason: reason);
          break;
        default:
          return const ClockActionResult(
            success: false, message: 'Unknown action');
      }
      return ClockActionResult(success: true, message: 'Success', data: result);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // device token invalid
        await AttendanceDeviceStorage.clearToken();
        state = const AttendanceDeviceState(
          status: AttendanceDeviceStatus.needsRegister,
          error: 'Device session expired. Please register again.',
        );
        return ClockActionResult(
          success: false,
          message: 'Device session expired. Please register again.',
        );
      }
      return ClockActionResult(
        success: false,
        message: _parseError(e, 'Action failed'),
        errorCode: _parseErrorCode(e),
        errorDetail: _parseErrorDetail(e),
      );
    } catch (e) {
      return ClockActionResult(success: false, message: 'Action failed');
    }
  }

  /// PIN-first kiosk identify — POST /attendance/identify-by-pin.
  ///
  /// 성공 시 typed [IdentifyResponse] 반환.
  /// 실패 (400 Invalid PIN / 422 형식 위반 / 401 device expired / 네트워크) 시 throws.
  /// 호출 측은 try/catch 로 메시지 변환.
  Future<IdentifyResponse> identifyUserByPin(String pin) async {
    final raw = await _service.identifyByPin(pin: pin);
    return IdentifyResponse.fromJson(raw);
  }

  /// 팁 분배 대상 후보 — PIN 인증 후 같은 매장/날/시간 겹친 staff.
  Future<List<TipReceiver>> getTipEligibleReceivers({
    required String userId,
    required String pin,
  }) async {
    final raw = await _service.getTipEligibleReceivers(userId: userId, pin: pin);
    return raw.map(TipReceiver.fromJson).toList();
  }

  /// 매장 전체 active 직원 — manual receiver 추가 검색용 (L5).
  Future<List<TipReceiver>> getStoreEmployees() async {
    final raw = await _service.getStoreEmployees();
    return raw.map(TipReceiver.fromJson).toList();
  }

  /// 팁 입력 제출. work_date 는 device.workDate 사용 (없으면 IllegalState).
  Future<ClockActionResult> submitTipEntry({
    required String userId,
    required String pin,
    required TipPayload payload,
  }) async {
    final workDate = state.device?.workDate;
    if (workDate == null || workDate.isEmpty) {
      return const ClockActionResult(
        success: false,
        message: 'No work date — device not ready',
      );
    }
    try {
      final raw = await _service.submitTipEntry(
        userId: userId,
        pin: pin,
        date: workDate,
        cardTips: payload.cardTips.toStringAsFixed(2),
        cashTipsKept: payload.cashTipsKept.toStringAsFixed(2),
        distributions: payload.distributions.map((d) => d.toJson()).toList(),
      );
      return ClockActionResult(success: true, message: 'Tip recorded', data: raw);
    } on DioException catch (e) {
      return ClockActionResult(
        success: false,
        message: _parseError(e, 'Tip submission failed'),
      );
    } catch (_) {
      return const ClockActionResult(success: false, message: 'Tip submission failed');
    }
  }

  /// 기기 고유 fingerprint를 생성/조회
  ///
  /// 첫 등록 시 생성 후 저장, 이후 동일한 값을 재사용.
  /// 서버가 fingerprint로 기기 레코드를 식별할 수 있도록 함.
  Future<String> _ensureFingerprint() async {
    final existing = await AttendanceDeviceStorage.getFingerprint();
    if (existing != null && existing.isNotEmpty) return existing;
    // 간단한 고유값: ts + random-like
    final seed =
        '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    await AttendanceDeviceStorage.setFingerprint(seed);
    return seed;
  }

  /// 구조화된 detail(dict) 에서 code 만 뽑는다. 없으면 null.
  String? _parseErrorCode(Object e) {
    final detail = _detailMap(e);
    final code = detail?['code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// 구조화된 detail(dict) 전체 — minutes_early 등 부가 정보용.
  Map<String, dynamic>? _parseErrorDetail(Object e) => _detailMap(e);

  Map<String, dynamic>? _detailMap(Object e) {
    if (e is DioException && e.response?.data is Map<String, dynamic>) {
      final detail = (e.response!.data as Map<String, dynamic>)['detail'];
      if (detail is Map<String, dynamic>) return detail;
    }
    return null;
  }

  /// Dio 에러를 사용자 친화적 메시지로 변환
  String _parseError(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map<String, dynamic>) {
      final data = e.response!.data as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      // 구조화된 detail — message 필드를 사람이 읽는 문장으로 쓴다.
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
    }
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server not responding. Please try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'No internet connection.';
      }
    }
    return fallback;
  }
}

/// Clock 액션 결과
class ClockActionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  /// 서버가 준 구조화된 실패 코드 (예: 'early_clock_in_reason_required').
  /// 메시지 문자열 매칭 대신 이걸로 후속 화면을 결정한다.
  final String? errorCode;

  /// 그 실패의 부가 정보 (minutes_early, schedule_id 등).
  final Map<String, dynamic>? errorDetail;

  const ClockActionResult({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
    this.errorDetail,
  });
}
