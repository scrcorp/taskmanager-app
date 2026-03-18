/// 스케줄 API 서비스
///
/// 업무역할 조회, 신청 CRUD, 확정 스케줄 조회, 템플릿 관리,
/// 내 스케줄(체크리스트 포함) 조회/완료/반려응답을 담당.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/my_schedule.dart';
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

  /// 배치 제출 — 여러 신청을 한번에 생성/수정/삭제
  Future<Map<String, dynamic>> batchSubmit({
    List<Map<String, dynamic>> creates = const [],
    List<Map<String, dynamic>> updates = const [],
    List<String> deletes = const [],
  }) async {
    final response = await _dio.post('/app/my/schedule-requests/batch', data: {
      'creates': creates,
      'updates': updates,
      'deletes': deletes,
    });
    return response.data as Map<String, dynamic>;
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

  /// 템플릿으로 신청 일괄 생성
  ///
  /// [weekStartDate] — 적용할 주 시작일 (yyyy-MM-dd)
  /// [templateId] — 적용할 템플릿 ID
  /// [onConflict] — 중복 처리: "skip" (기본) | "replace"
  ///
  /// 응답: { created: [...], skipped: [...], replaced: [...] }
  Future<Map<String, dynamic>> createRequestsFromTemplate({
    required String templateId,
    required String storeId,
    required String dateFrom,
    required String dateTo,
    String onConflict = 'skip',
  }) async {
    final response = await _dio.post(
      '/app/my/schedule-requests/from-template',
      data: {
        'template_id': templateId,
        'store_id': storeId,
        'date_from': dateFrom,
        'date_to': dateTo,
        'on_conflict': onConflict,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// 지난 주 신청 복사
  ///
  /// [weekStartDate] — 복사할 대상 주 시작일 (yyyy-MM-dd)
  /// [onConflict] — 중복 처리: "skip" (기본) | "replace"
  ///
  /// 응답: { created: [...], skipped: [...], replaced: [...] }
  Future<Map<String, dynamic>> copyLastPeriod({
    required String storeId,
    required String dateFrom,
    required String dateTo,
    String onConflict = 'skip',
  }) async {
    final response = await _dio.post(
      '/app/my/schedule-requests/copy-last-period',
      data: {
        'store_id': storeId,
        'date_from': dateFrom,
        'date_to': dateTo,
        'on_conflict': onConflict,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── 내 스케줄 (체크리스트 포함, 기존 work-assignments 대체) ──

  /// 내 스케줄 목록 조회 — 날짜/상태 필터 지원
  ///
  /// 응답 형식이 배열 또는 { items/data: [...] } 모두 대응.
  Future<List<MySchedule>> getMySchedules({String? workDate, String? status}) async {
    final params = <String, dynamic>{};
    if (workDate != null) params['work_date'] = workDate;
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/schedules', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => MySchedule.fromJson(e)).toList();
  }

  /// 스케줄 상세 조회 — 체크리스트, 매장 정보 포함
  Future<MySchedule> getMyScheduleDetail(String id) async {
    final response = await _dio.get('/app/my/schedules/$id');
    return MySchedule.fromJson(response.data);
  }

  /// 과거 스케줄 조회 — 날짜 범위 + 페이지네이션
  Future<PaginatedMySchedules> getPastMySchedules({
    required String dateTo,
    String? dateFrom,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'date_to': dateTo,
      'page': page,
      'per_page': perPage,
      'sort': 'desc',
    };
    if (dateFrom != null) params['date_from'] = dateFrom;

    final response = await _dio.get('/app/my/schedules', queryParameters: params);
    return PaginatedMySchedules.fromJson(response.data as Map<String, dynamic>);
  }

  /// 체크리스트 항목 완료 처리 (새 API: POST /checklist-instances/{instanceId}/items/{idx}/complete)
  Future<void> completeChecklistItem(
    String instanceId,
    int itemIndex, {
    String? timezone,
    List<String>? photoUrls,
    String? note,
  }) async {
    await _dio.post('/app/my/checklist-instances/$instanceId/items/$itemIndex/complete', data: {
      if (timezone != null) 'timezone': timezone,
      if (photoUrls != null && photoUrls.isNotEmpty) 'photo_urls': photoUrls,
      if (note != null) 'note': note,
    });
  }

  /// 체크리스트 항목 완료/미완료 토글 (구 API — uncomplete는 별도 엔드포인트)
  Future<void> toggleChecklistItem(
    String scheduleId,
    int itemIndex,
    bool isCompleted, {
    String? timezone,
    List<String>? photoUrls,
    String? note,
  }) async {
    await _dio.patch('/app/my/schedules/$scheduleId/checklist/$itemIndex', data: {
      'is_completed': isCompleted,
      if (timezone != null) 'timezone': timezone,
      if (photoUrls != null && photoUrls.isNotEmpty) 'photo_urls': photoUrls,
      if (note != null) 'note': note,
    });
  }

  /// 반려된 체크리스트 항목에 재응답 (새 API: PUT /checklist-instances/{instanceId}/items/{idx}/resubmit)
  Future<void> respondToRejection(
    String scheduleId,
    int itemIndex, {
    String? instanceId,
    String? responseComment,
    List<String>? photoUrls,
    String? timezone,
  }) async {
    if (instanceId != null) {
      // 새 API 사용
      await _dio.put('/app/my/checklist-instances/$instanceId/items/$itemIndex/resubmit', data: {
        if (timezone != null) 'client_timezone': timezone,
        if (responseComment != null) 'note': responseComment,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photo_urls': photoUrls,
      });
    } else {
      // 구 API fallback
      await _dio.patch('/app/my/schedules/$scheduleId/checklist/$itemIndex/respond', data: {
        if (timezone != null) 'timezone': timezone,
        if (responseComment != null) 'response_comment': responseComment,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photo_urls': photoUrls,
      });
    }
  }

  /// 완료된 체크리스트 항목 미완료로 되돌리기 (리뷰 없을 때만 가능)
  Future<void> uncompleteItem(String instanceId, int itemIndex) async {
    await _dio.delete('/app/my/checklist-instances/$instanceId/items/$itemIndex/uncomplete');
  }

  /// 체크리스트 완료 리포트 제출
  Future<void> sendReport(String instanceId) async {
    await _dio.post('/app/my/checklist-instances/$instanceId/report');
  }

  /// 리뷰 채팅에 콘텐츠 추가 (텍스트/사진)
  Future<void> addReviewContent(
    String instanceId,
    int itemIndex, {
    required String type,
    required String content,
  }) async {
    await _dio.post(
      '/app/my/checklist-instances/$instanceId/items/$itemIndex/review/contents',
      data: {'type': type, 'content': content},
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
