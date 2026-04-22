/// Clock In/Out 서비스 — 출퇴근 및 휴게 API 호출
///
/// 매장 키오스크(패드)에서 사용하는 출퇴근 관련 API:
/// - PIN 인증 → clock in / clock out / break 처리
/// - 현재 근무 중인 직원 목록 조회
/// - 다음 근무 예정자 목록 조회
/// - 매장 목록 조회 (키오스크 설정용)
///
/// 모든 clock 요청에 store_id를 포함하여 매장별 데이터를 처리.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// ClockService Provider
final clockServiceProvider = Provider<ClockService>((ref) {
  return ClockService(ref.read(dioProvider));
});

class ClockService {
  final Dio dio;
  ClockService(this.dio);

  /// Clock In
  Future<Map<String, dynamic>> clockIn(String pin, {String? storeId}) async {
    final res = await dio.post('/clock/in', data: {
      'pin': pin,
      if (storeId != null) 'store_id': storeId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Clock Out
  Future<Map<String, dynamic>> clockOut(String pin, {String? storeId}) async {
    final res = await dio.post('/clock/out', data: {
      'pin': pin,
      if (storeId != null) 'store_id': storeId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Break 시작/종료
  Future<Map<String, dynamic>> toggleBreak(String pin, {String? storeId}) async {
    final res = await dio.post('/clock/break', data: {
      'pin': pin,
      if (storeId != null) 'store_id': storeId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// 현재 근무 중인 직원 목록
  Future<List<dynamic>> getOnShift({String? storeId}) async {
    final res = await dio.get('/clock/on-shift', queryParameters: {
      if (storeId != null) 'store_id': storeId,
    });
    return res.data as List<dynamic>;
  }

  /// 다음 근무 예정자 목록
  Future<List<dynamic>> getComingUp({String? storeId}) async {
    final res = await dio.get('/clock/coming-up', queryParameters: {
      if (storeId != null) 'store_id': storeId,
    });
    return res.data as List<dynamic>;
  }

  /// 매장 목록 조회 (키오스크 설정용)
  Future<List<dynamic>> getStores() async {
    final res = await dio.get('/app/my/stores');
    return res.data as List<dynamic>;
  }

  /// 이번 달 근태 요약 (모바일용)
  Future<Map<String, dynamic>> getAttendanceSummary() async {
    final res = await dio.get('/app/my/attendance/summary');
    return res.data as Map<String, dynamic>;
  }

  /// 오늘 같이 근무하는 동료 목록 (모바일용)
  Future<List<dynamic>> getTodayTeam() async {
    final res = await dio.get('/app/my/today-team');
    return res.data as List<dynamic>;
  }
}
