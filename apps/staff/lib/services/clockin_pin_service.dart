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

/// PIN 저장 실패 (409 충돌 / 422 형식 오류) — 서버 detail(dict)을 보존해
/// UI 가 사유(exact/prefix)별로 다른 안내를 표시할 수 있게 한다.
///
/// 409 계약: detail = {code: "pin_conflict", reason: "exact"|"prefix",
///           other_store: bool|null, message: "<영어 사유 문장>"}
/// 422: FastAPI validation error (detail 이 dict 가 아닐 수 있음 → 빈 맵).
class PinUpdateException implements Exception {
  /// 409 또는 422
  final int statusCode;

  /// 응답 body 의 detail dict (dict 가 아니면 빈 맵)
  final Map<String, dynamic> detail;

  const PinUpdateException({required this.statusCode, required this.detail});

  String? get code => detail['code'] as String?;
  String? get reason => detail['reason'] as String?;

  /// 409 + code=pin_conflict — 타인 PIN 과 충돌
  bool get isPinConflict => statusCode == 409 && code == 'pin_conflict';

  /// 422 — PIN 형식 오류 (4~6자리 숫자 아님)
  bool get isInvalidFormat => statusCode == 422;

  /// DioException 응답 body 에서 detail dict 추출 (dict 아니면 빈 맵)
  static Map<String, dynamic> extractDetail(dynamic data) {
    if (data is Map && data['detail'] is Map) {
      return Map<String, dynamic>.from(data['detail'] as Map);
    }
    return const {};
  }

  @override
  String toString() =>
      'PinUpdateException(statusCode: $statusCode, detail: $detail)';
}

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
  /// 409(충돌)/422(형식) → PinUpdateException (detail dict 보존)
  /// 그 외 오류 → DioException rethrow
  Future<Map<String, dynamic>> updatePin(String pin) async {
    try {
      final response = await _dio.put(
        '/app/profile/clockin-pin',
        data: {'clockin_pin': pin},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409 || code == 422) {
        throw PinUpdateException(
          statusCode: code!,
          detail: PinUpdateException.extractDetail(e.response?.data),
        );
      }
      rethrow;
    }
  }
}
