/// 근무배정(Work Assignment) API 서비스
///
/// 오늘/과거 근무배정 조회, 체크리스트 항목 완료/미완료 토글,
/// 반려된 항목 재응답 API를 호출.
/// 엔드포인트: /app/my/work-assignments/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import 'api_client.dart';

/// 근무배정 서비스 Provider
final assignmentServiceProvider = Provider<AssignmentService>((ref) {
  return AssignmentService(ref.read(dioProvider));
});

/// 근무배정 API 서비스 클래스
class AssignmentService {
  final Dio _dio;

  AssignmentService(this._dio);

  /// 내 근무배정 목록 조회 — 날짜/상태 필터 지원
  ///
  /// 응답 형식이 배열 또는 { items/data: [...] } 모두 대응.
  Future<List<Assignment>> getMyAssignments({String? workDate, String? status}) async {
    final params = <String, dynamic>{};
    if (workDate != null) params['work_date'] = workDate;
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/work-assignments', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Assignment.fromJson(e)).toList();
  }

  /// 근무배정 상세 조회 — 체크리스트, 매장 정보 포함
  Future<Assignment> getAssignment(String id) async {
    final response = await _dio.get('/app/my/work-assignments/$id');
    return Assignment.fromJson(response.data);
  }

  /// 과거 근무배정 조회 — 날짜 범위 + 페이지네이션
  ///
  /// 서버가 { items, total, page, per_page } 형태로 응답하며
  /// PaginatedAssignments 모델로 파싱.
  Future<PaginatedAssignments> getPastAssignments({
    required String dateTo,
    String? dateFrom,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'date_to': dateTo,
      'page': page,
      'per_page': perPage,
    };
    if (dateFrom != null) params['date_from'] = dateFrom;

    final response = await _dio.get('/app/my/work-assignments', queryParameters: params);
    return PaginatedAssignments.fromJson(response.data as Map<String, dynamic>);
  }

  /// 체크리스트 항목 완료/미완료 토글
  ///
  /// [itemIndex]: 체크리스트 내 항목 인덱스 (0부터)
  /// [photoUrl]/[note]: 사진/메모가 필요한 항목의 경우 선택적 첨부
  /// [timezone]: 완료 시각 기록용 타임존 (미지정 시 서버가 매장 타임존 사용)
  Future<void> toggleChecklistItem(
    String assignmentId,
    int itemIndex,
    bool isCompleted, {
    String? timezone,
    String? photoUrl,
    String? note,
  }) async {
    await _dio.patch('/app/my/work-assignments/$assignmentId/checklist/$itemIndex', data: {
      'is_completed': isCompleted,
      if (timezone != null) 'timezone': timezone,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (note != null) 'note': note,
    });
  }

  /// 반려된 체크리스트 항목에 재응답
  ///
  /// 관리자가 반려한 항목에 대해 직원이 추가 코멘트/사진으로 재제출.
  Future<void> respondToRejection(
    String assignmentId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
    String? timezone,
  }) async {
    await _dio.patch('/app/my/work-assignments/$assignmentId/checklist/$itemIndex/respond', data: {
      if (timezone != null) 'timezone': timezone,
      if (responseComment != null) 'response_comment': responseComment,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }
}
