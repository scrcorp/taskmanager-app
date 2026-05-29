/// 태블릿 기기(device) attendance API 서비스
///
/// 매장 공용 태블릿 kiosk 용 별도 auth scope.
/// 일반 JWT(TokenStorage)가 아닌 device token을 Authorization 헤더로 사용.
///
/// 주요 엔드포인트:
/// - POST /attendance/register — access code로 기기 등록 (token 발급)
/// - GET  /attendance/me       — 기기 정보 조회 (401이면 토큰 무효)
/// - PUT  /attendance/store    — 매장 할당/변경
/// - DELETE /attendance/me     — 기기 해제
/// - POST /attendance/clock-in | clock-out | break-start | break-end (body: pin)
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../utils/attendance_device_storage.dart';

/// Device attendance 서비스 Provider (전용 Dio 인스턴스 내장)
final attendanceDeviceServiceProvider = Provider<AttendanceDeviceService>((ref) {
  return AttendanceDeviceService();
});

/// 서버 응답 헤더로 piggyback 되는 앱 버전 정보.
///
/// X-App-Latest-Version / X-App-Min-Version / X-App-Download-Url
/// 매 응답마다 갱신됨 — Shell 가 listen 해서 즉시 배너/blocker 표시.
@immutable
class VersionBroadcast {
  final String? latestVersion;
  final String? minVersion;
  final String? downloadUrl;

  const VersionBroadcast({this.latestVersion, this.minVersion, this.downloadUrl});

  bool sameAs(VersionBroadcast? other) =>
      other != null &&
      latestVersion == other.latestVersion &&
      minVersion == other.minVersion &&
      downloadUrl == other.downloadUrl;
}

/// Device 인증 전용 Dio 클라이언트
class AttendanceDeviceService {
  late final Dio _dio;
  /// 키오스크 관리자 모드 세션 토큰 (in-memory).
  /// `_ManageSessionInterceptor` 가 있을 때만 `X-Manage-Session` 헤더를 추가한다.
  String? _manageToken;

  /// 최근 응답에서 추출된 서버 버전 정보. Shell 가 listen 해서 갱신.
  final ValueNotifier<VersionBroadcast?> versionBroadcast = ValueNotifier(null);

  AttendanceDeviceService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    // device token 자동 주입 (있을 때만)
    _dio.interceptors.add(_DeviceAuthInterceptor());
    _dio.interceptors.add(_ManageSessionInterceptor(() => _manageToken));
    // 응답 헤더에서 X-App-* 추출 → versionBroadcast 갱신
    _dio.interceptors.add(_VersionBroadcastInterceptor(versionBroadcast));
  }

  void setManageToken(String? token) {
    _manageToken = token;
  }

  /// Access code로 기기 등록 — 성공 시 토큰 발급
  ///
  /// [accessCode]: 관리자가 발급한 6자 code (영숫자, 대문자 자동변환)
  /// [fingerprint]: 선택. 로컬에 저장된 값을 재사용하여 전달.
  Future<Map<String, dynamic>> register({
    required String accessCode,
    String? fingerprint,
  }) async {
    final response = await _dio.post('/attendance/register', data: {
      'access_code': accessCode.toUpperCase().trim(),
      if (fingerprint != null && fingerprint.isNotEmpty) 'fingerprint': fingerprint,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 기기 정보 조회 — 토큰 유효성 검증용 (401이면 토큰 삭제 필요)
  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/attendance/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 앱 버전 정보 — sideload APK update enforcement 용.
  /// 응답 필드 (모두 nullable):
  ///   { min_version, latest_version, download_url, release_notes }
  Future<Map<String, dynamic>> getAppVersion() async {
    final response = await _dio.get('/attendance/app-version');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 매장 할당/변경
  Future<Map<String, dynamic>> setStore(String storeId) async {
    final response = await _dio.put('/attendance/store', data: {
      'store_id': storeId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Device token으로 조직 내 매장 후보 조회
  Future<List<Map<String, dynamic>>> listStores() async {
    final response = await _dio.get('/attendance/stores');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 기기 해제 (unregister) — 서버의 기기 레코드 제거
  Future<void> unregister() async {
    await _dio.delete('/attendance/me');
  }

  /// Clock In — user_id + PIN(4~6) 으로 출근 기록.
  /// (Issue 8) scheduleId 지정 시 그 schedule 에 출근 (다중 schedule picker).
  Future<Map<String, dynamic>> clockIn({
    required String userId,
    required String pin,
    String? scheduleId,
  }) async {
    return _postAction(
      '/attendance/clock-in',
      userId: userId,
      pin: pin,
      extra: scheduleId != null ? {'schedule_id': scheduleId} : null,
    );
  }

  /// Clock Out — user_id + 6자리 PIN으로 퇴근 기록.
  /// [reason] 은 schedule end 의 early-leave threshold 이전 clock-out 시 필수.
  Future<Map<String, dynamic>> clockOut({
    required String userId,
    required String pin,
    String? reason,
  }) async {
    return _postAction(
      '/attendance/clock-out',
      userId: userId,
      pin: pin,
      extra: (reason != null && reason.trim().isNotEmpty)
          ? {'reason': reason.trim()}
          : null,
    );
  }

  /// Break Start — user_id + 6자리 PIN으로 휴식 시작
  ///
  /// [breakType] — 'paid_10min' (10분 유급) 또는 'unpaid_meal' (무급 식사)
  Future<Map<String, dynamic>> breakStart({
    required String userId,
    required String pin,
    required String breakType,
  }) async {
    return _postAction(
      '/attendance/break-start',
      userId: userId,
      pin: pin,
      extra: {'break_type': breakType},
    );
  }

  /// Break End — user_id + 6자리 PIN으로 휴식 종료
  Future<Map<String, dynamic>> breakEnd({
    required String userId,
    required String pin,
  }) async {
    return _postAction('/attendance/break-end', userId: userId, pin: pin);
  }

  /// PIN 단독으로 본인 식별 + 오늘 attendance status (Phase 3, PIN-first kiosk entry).
  ///
  /// Phase 5 의 본인 확인 다이얼로그에서 사용 예정. 현재는 dormant (호출하는 UI 없음).
  ///
  /// [pin] — 6자리 숫자
  ///
  /// 응답: { user_id, user_name, today_status }
  ///   - today_status: 오늘 스케줄 있으면 'working'/'upcoming'/'late'/'no_show'/'soon'/
  ///                   'on_break'/'clocked_out', 없으면 null
  ///
  /// Throws DioException — 매치 없음/비활성 user → 400 'Invalid PIN',
  ///                       PIN 형식 위반 → 422.
  Future<Map<String, dynamic>> identifyByPin({required String pin}) async {
    final response = await _dio.post(
      '/attendance/identify-by-pin',
      data: {'pin': pin},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 오늘 매장 근무자 상태 조회 (device token)
  ///
  /// 응답: 각 유저의 schedule + attendance 요약 리스트
  Future<List<Map<String, dynamic>>> getTodayStaff() async {
    final response = await _dio.get('/attendance/today-staff');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 팁 분배 대상 후보 — PIN 인증 후 같은 매장/날/시간 겹친 staff 목록.
  Future<List<Map<String, dynamic>>> getTipEligibleReceivers({
    required String userId,
    required String pin,
  }) async {
    final response = await _dio.post(
      '/attendance/tip-entry/eligible-receivers',
      data: {'user_id': userId, 'pin': pin},
    );
    final list = response.data as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 매장 전체 active 직원 — manual tip receiver 추가용 (L5).
  /// 한 번에 받아 client-side 검색 필터. payload ~5KB 수준이라 paging 없음.
  Future<List<Map<String, dynamic>>> getStoreEmployees() async {
    final response = await _dio.get('/attendance/store-employees');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 팁 입력 — clock-out 직후 매장 비치 태블릿에서 호출.
  ///
  /// distributions: 각 항목 {receiver_id, amount, reason?}.
  /// 분배 합 > card_tips 면 서버가 400 반환.
  Future<Map<String, dynamic>> submitTipEntry({
    required String userId,
    required String pin,
    required String date,
    required String cardTips,
    required String cashTipsKept,
    String? workRoleId,
    List<Map<String, dynamic>> distributions = const [],
  }) async {
    final response = await _dio.post(
      '/attendance/tip-entry',
      data: {
        'user_id': userId,
        'pin': pin,
        'date': date,
        'card_tips': cardTips,
        'cash_tips_kept': cashTipsKept,
        if (workRoleId != null) 'work_role_id': workRoleId,
        'distributions': distributions,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> _postAction(
    String path, {
    required String userId,
    required String pin,
    Map<String, dynamic>? extra,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'pin': pin,
      ...?extra,
    };
    final response = await _dio.post(path, data: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── Manage 모드 (kiosk manage) ─────────────────────────────

  /// 매니저 PIN 검증 + manage session 발급. 성공 시 setManageToken 자동 호출.
  /// Phase 6: user_id 없이 PIN 하나로 user 식별 + 자격 검증 (서버에서).
  Future<Map<String, dynamic>> openManageSession({
    required String pin,
  }) async {
    final response = await _dio.post('/attendance/manage/session', data: {
      'pin': pin,
    });
    final body = Map<String, dynamic>.from(response.data as Map);
    final token = body['manage_token'] as String?;
    if (token != null && token.isNotEmpty) {
      setManageToken(token);
    }
    return body;
  }

  /// admin session 종료 (서버 폐기 + 로컬 토큰 제거). 실패해도 로컬은 클리어.
  Future<void> closeManageSession() async {
    try {
      await _dio.delete('/attendance/manage/session');
    } catch (_) {
      // 서버 통신 실패해도 로컬 클리어로 안전 종료
    }
    setManageToken(null);
  }

  /// 오늘 매장 스케줄 (관리자 모드 리스트).
  Future<List<Map<String, dynamic>>> manageListSchedules() async {
    final response = await _dio.get('/attendance/manage/schedules');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 매장에 work_assignment 된 직원 목록 (스케줄 생성 select).
  Future<List<Map<String, dynamic>>> manageListAssignableUsers() async {
    final response = await _dio.get('/attendance/manage/assignable-users');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 매장 work role 목록 (스케줄 생성 select).
  Future<List<Map<String, dynamic>>> manageListWorkRoles() async {
    final response = await _dio.get('/attendance/manage/work-roles');
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> manageCreateSchedule({
    required String userId,
    String? workRoleId,
    required String startHHmm,
    required String endHHmm,
  }) async {
    final response = await _dio.post('/attendance/manage/schedules', data: {
      'user_id': userId,
      if (workRoleId != null) 'work_role_id': workRoleId,
      'start_time': startHHmm,
      'end_time': endHHmm,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> manageUpdateSchedule({
    required String scheduleId,
    String? userId,
    String? workRoleId,
    String? startHHmm,
    String? endHHmm,
  }) async {
    final body = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      if (workRoleId != null) 'work_role_id': workRoleId,
      if (startHHmm != null) 'start_time': startHHmm,
      if (endHHmm != null) 'end_time': endHHmm,
    };
    final response = await _dio.patch(
      '/attendance/manage/schedules/$scheduleId',
      data: body,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> manageDeleteSchedule(String scheduleId) async {
    await _dio.delete('/attendance/manage/schedules/$scheduleId');
  }

  /// 관리자가 임의 사용자 attendance 를 PIN 없이 처리.
  /// actions: clock_in | clock_out | break_start | break_end | cancel_clock_in | cancel_clock_out
  Future<Map<String, dynamic>> manageClockAction({
    required String userId,
    required String action,
    String? breakType,
    String? reason,
  }) async {
    final response = await _dio.post('/attendance/manage/clock', data: {
      'user_id': userId,
      'action': action,
      if (breakType != null) 'break_type': breakType,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 관리자가 status 와 시각을 동시에 보정.
  /// status: working | late | on_break | clocked_out | upcoming | no_show
  Future<Map<String, dynamic>> manageChangeStatus({
    required String userId,
    required String status,
    required String reason,
    String? clockInHHmm,
    String? clockOutHHmm,
  }) async {
    final response = await _dio.post(
      '/attendance/manage/attendance/status',
      data: {
        'user_id': userId,
        'status': status,
        'reason': reason,
        if (clockInHHmm != null) 'clock_in_hhmm': clockInHHmm,
        if (clockOutHHmm != null) 'clock_out_hhmm': clockOutHHmm,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}

/// Device 토큰을 Authorization 헤더로 자동 주입
class _DeviceAuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await AttendanceDeviceStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// In-memory admin session token 을 X-Manage-Session 헤더로 자동 주입
class _ManageSessionInterceptor extends Interceptor {
  final String? Function() _getter;
  _ManageSessionInterceptor(this._getter);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _getter();
    if (token != null && token.isNotEmpty) {
      options.headers['X-Manage-Session'] = token;
    }
    handler.next(options);
  }
}

/// 응답 헤더 X-App-Latest-Version / X-App-Min-Version / X-App-Download-Url
/// 을 읽어 versionBroadcast 를 갱신. 같은 값이면 notify 생략 (rebuild 최소화).
/// 401 등 에러 응답에도 헤더는 박혀오므로 onError 에서도 동일 처리.
class _VersionBroadcastInterceptor extends Interceptor {
  final ValueNotifier<VersionBroadcast?> _notifier;
  _VersionBroadcastInterceptor(this._notifier);

  void _extract(Headers? h) {
    if (h == null) return;
    final latest = h.value('x-app-latest-version');
    final min = h.value('x-app-min-version');
    final url = h.value('x-app-download-url');
    if (latest == null && min == null && url == null) return;
    final next = VersionBroadcast(
      latestVersion: latest,
      minVersion: min,
      downloadUrl: url,
    );
    if (!next.sameAs(_notifier.value)) {
      _notifier.value = next;
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _extract(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _extract(err.response?.headers);
    handler.next(err);
  }
}
