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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../utils/attendance_device_storage.dart';

/// Device attendance 서비스 Provider (전용 Dio 인스턴스 내장)
final attendanceDeviceServiceProvider = Provider<AttendanceDeviceService>((ref) {
  return AttendanceDeviceService();
});

/// Device 인증 전용 Dio 클라이언트
class AttendanceDeviceService {
  late final Dio _dio;

  AttendanceDeviceService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    // device token 자동 주입 (있을 때만)
    _dio.interceptors.add(_DeviceAuthInterceptor());
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

  /// Clock In — user_id + 6자리 PIN으로 출근 기록
  Future<Map<String, dynamic>> clockIn({
    required String userId,
    required String pin,
  }) async {
    return _postAction('/attendance/clock-in', userId: userId, pin: pin);
  }

  /// Clock Out — user_id + 6자리 PIN으로 퇴근 기록
  Future<Map<String, dynamic>> clockOut({
    required String userId,
    required String pin,
  }) async {
    return _postAction('/attendance/clock-out', userId: userId, pin: pin);
  }

  /// Break Start — user_id + 6자리 PIN으로 휴식 시작
  ///
  /// [breakType] — 'paid_short' (10분 유급) 또는 'unpaid_long' (30분 무급)
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

  /// 매장 공지 조회 (device token)
  Future<List<Map<String, dynamic>>> getNotices({int limit = 10}) async {
    final response = await _dio.get(
      '/attendance/notices',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
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
