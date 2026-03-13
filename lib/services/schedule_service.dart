/// 스케줄 API 서비스
///
/// 업무역할 조회, 신청 CRUD, 확정 스케줄 조회, 템플릿 관리를 담당.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import 'api_client.dart';

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService(ref.read(dioProvider));
});

class ScheduleService {
  final Dio _dio;

  ScheduleService(this._dio);

  /// 내 매장 목록 조회
  Future<List<Map<String, dynamic>>> getMyStores() async {
    final response = await _dio.get('/app/my/stores');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// 업무역할 목록 조회 (storeId 생략 시 전체)
  Future<List<WorkRole>> getWorkRoles({String? storeId}) async {
    final params = <String, dynamic>{};
    if (storeId != null) params['store_id'] = storeId;
    final response =
        await _dio.get('/app/my/work-roles', queryParameters: params);
    return (response.data as List)
        .map((e) => WorkRole.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내 스케줄 신청 목록 (날짜 범위 필터)
  Future<List<ScheduleRequest>> getMyRequests({
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final response =
        await _dio.get('/app/my/schedule-requests', queryParameters: params);
    return (response.data as List)
        .map((e) => ScheduleRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 스케줄 신청 제출
  Future<ScheduleRequest> submitRequest({
    required String storeId,
    required DateTime workDate,
    String? workRoleId,
    String? preferredStartTime,
    String? preferredEndTime,
    String? note,
  }) async {
    final data = <String, dynamic>{
      'store_id': storeId,
      'work_date': _formatDate(workDate),
      if (workRoleId != null) 'work_role_id': workRoleId,
      if (preferredStartTime != null)
        'preferred_start_time': preferredStartTime,
      if (preferredEndTime != null) 'preferred_end_time': preferredEndTime,
      if (note != null) 'note': note,
    };
    final response =
        await _dio.post('/app/my/schedule-requests', data: data);
    return ScheduleRequest.fromJson(response.data);
  }

  /// 스케줄 신청 수정
  Future<ScheduleRequest> updateRequest(
    String requestId, {
    String? storeId,
    String? workRoleId,
    String? preferredStartTime,
    String? preferredEndTime,
    String? note,
  }) async {
    final data = <String, dynamic>{
      if (storeId != null) 'store_id': storeId,
      if (workRoleId != null) 'work_role_id': workRoleId,
      if (preferredStartTime != null)
        'preferred_start_time': preferredStartTime,
      if (preferredEndTime != null) 'preferred_end_time': preferredEndTime,
      if (note != null) 'note': note,
    };
    final response =
        await _dio.put('/app/my/schedule-requests/$requestId', data: data);
    return ScheduleRequest.fromJson(response.data);
  }

  /// 스케줄 신청 삭제
  Future<void> deleteRequest(String requestId) async {
    await _dio.delete('/app/my/schedule-requests/$requestId');
  }

  /// 내 확정 스케줄 조회
  Future<List<ScheduleEntry>> getMyEntries({
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final response =
        await _dio.get('/app/my/schedules', queryParameters: params);
    return (response.data as List)
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내 템플릿 목록 조회
  Future<List<ScheduleTemplate>> getMyTemplates() async {
    try {
      final response = await _dio.get('/app/my/schedule-templates');
      return (response.data as List)
          .map((e) => ScheduleTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 템플릿 생성
  Future<ScheduleTemplate> createTemplate({
    required String name,
    required bool isDefault,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.post('/app/my/schedule-templates', data: {
      'name': name,
      'is_default': isDefault,
      'items': items,
    });
    return ScheduleTemplate.fromJson(response.data);
  }

  /// 템플릿 수정
  Future<ScheduleTemplate> updateTemplate(
    String templateId, {
    required String name,
    required bool isDefault,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.put('/app/my/schedule-templates/$templateId', data: {
      'name': name,
      'is_default': isDefault,
      'items': items,
    });
    return ScheduleTemplate.fromJson(response.data);
  }

  /// 템플릿 삭제
  Future<void> deleteTemplate(String templateId) async {
    await _dio.delete('/app/my/schedule-templates/$templateId');
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
