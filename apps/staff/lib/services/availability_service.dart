/// 근무 가용성(Work Availability) API 서비스
///
/// 직원 본인의 주간 가용성 조회 + (셀프 편집 허용 시) 저장.
/// 엔드포인트: /app/my/availability (GET / PUT)
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/availability.dart';
import 'api_client.dart';

/// 가용성 서비스 Provider
final availabilityServiceProvider = Provider<AvailabilityService>((ref) {
  return AvailabilityService(ref.read(dioProvider));
});

/// 가용성 API 서비스 클래스
class AvailabilityService {
  final Dio _dio;

  AvailabilityService(this._dio);

  /// 내 주간 가용성 조회
  Future<MyAvailability> getMyAvailability() async {
    final response = await _dio.get('/app/my/availability');
    return MyAvailability.fromJson(response.data as Map<String, dynamic>);
  }

  /// 내 주간 가용성 저장 (셀프 편집 — can_edit 인 경우에만 서버가 허용).
  /// [days] 는 Sun→Sat 7일 전부. 저장된 최신 상태를 돌려준다.
  Future<MyAvailability> updateMyAvailability(List<AvailabilityDay> days) async {
    final response = await _dio.put(
      '/app/my/availability',
      data: {'days': days.map((d) => d.toJson()).toList()},
    );
    return MyAvailability.fromJson(response.data as Map<String, dynamic>);
  }
}
