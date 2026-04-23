/// 본인 clock-in PIN 조회/재생성 서비스 (JWT 인증)
///
/// MyPage의 "Clock-in PIN" 섹션에서 사용.
/// JWT 인증이 필요하므로 기존 dioProvider(AuthInterceptor 사용) 재사용.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// clock-in PIN 서비스 Provider
final clockinPinServiceProvider = Provider<ClockinPinService>((ref) {
  return ClockinPinService(ref.read(dioProvider));
});

/// clock-in PIN API 서비스 (JWT 인증)
class ClockinPinService {
  final Dio _dio;
  ClockinPinService(this._dio);

  /// 본인 PIN 조회 — { user_id, clockin_pin }
  Future<Map<String, dynamic>> getPin() async {
    final response = await _dio.get('/app/profile/clockin-pin');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 본인 PIN 재생성 — 새 PIN 반환
  Future<Map<String, dynamic>> regeneratePin() async {
    final response = await _dio.post('/app/profile/clockin-pin/regenerate');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
