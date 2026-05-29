/// 본인 clock-in PIN 조회/재생성/변경 서비스 (JWT 인증)
///
/// MyPage의 "Clock-in PIN" 섹션에서 사용.
/// JWT 인증이 필요하므로 dioProvider(AuthInterceptor 포함) 재사용.
/// PIN 길이: 4~6자리 숫자 (Phase 5 Stage J 이후 가변).
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final clockinPinServiceProvider = Provider<ClockinPinService>((ref) {
  return ClockinPinService(ref.read(dioProvider));
});

class ClockinPinService {
  final Dio _dio;
  ClockinPinService(this._dio);

  /// 본인 PIN 조회 — { user_id, clockin_pin }
  Future<Map<String, dynamic>> getPin() async {
    final response = await _dio.get('/app/profile/clockin-pin');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 본인 PIN 재생성 (서버에서 랜덤 6자리 생성) — 새 PIN 반환
  Future<Map<String, dynamic>> regeneratePin() async {
    final response = await _dio.post('/app/profile/clockin-pin/regenerate');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 본인 PIN 직접 지정 (4~6자리 숫자) — 새 PIN 반환
  /// unique 위반 (409/422) → Exception('pin_not_available') throw
  Future<Map<String, dynamic>> updatePin(String pin) async {
    try {
      final response = await _dio.put(
        '/app/profile/clockin-pin',
        data: {'clockin_pin': pin},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409 || code == 422) throw Exception('pin_not_available');
      rethrow;
    }
  }
}
