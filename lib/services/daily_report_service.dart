/// Daily Report API 서비스
///
/// 일일 리포트 템플릿 조회, 리포트 CRUD, 제출 API를 호출.
/// 엔드포인트: /app/my/daily-reports/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_report.dart';
import 'api_client.dart';

/// Daily Report 서비스 Provider
final dailyReportServiceProvider = Provider<DailyReportService>((ref) {
  return DailyReportService(ref.read(dioProvider));
});

/// Daily Report API 서비스 클래스
class DailyReportService {
  final Dio _dio;

  DailyReportService(this._dio);

  /// 내 매장 목록 조회 — user_stores 기반
  Future<List<Map<String, dynamic>>> getMyStores() async {
    final response = await _dio.get('/app/my/stores');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// 리포트 템플릿 조회 — 섹션 폼 렌더링용
  Future<DailyReportTemplate> getTemplate({String? storeId}) async {
    final params = <String, dynamic>{};
    if (storeId != null) params['store_id'] = storeId;

    final response = await _dio.get(
      '/app/my/daily-reports/template',
      queryParameters: params,
    );
    return DailyReportTemplate.fromJson(response.data);
  }

  /// 내 리포트 목록 조회 — 페이지네이션 + 상태 필터
  Future<({List<DailyReport> items, int total})> getMyReports({
    String? storeId,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (storeId != null) params['store_id'] = storeId;
    if (status != null) params['status'] = status;

    final response = await _dio.get(
      '/app/my/daily-reports',
      queryParameters: params,
    );
    final data = response.data;
    final list = data['items'] as List? ?? [];
    return (
      items: list.map((e) => DailyReport.fromJson(e)).toList(),
      total: data['total'] as int? ?? list.length,
    );
  }

  /// 리포트 상세 조회 — 섹션 + 댓글 포함
  Future<DailyReport> getReport(String id) async {
    final response = await _dio.get('/app/my/daily-reports/$id');
    return DailyReport.fromJson(response.data);
  }

  /// 리포트 생성 — 빈 draft 리포트 생성 (템플릿 섹션 자동 복사)
  Future<DailyReport> createReport({
    required String storeId,
    required String reportDate,
    required String period,
    String? templateId,
  }) async {
    final response = await _dio.post('/app/my/daily-reports', data: {
      'store_id': storeId,
      'report_date': reportDate,
      'period': period,
      if (templateId != null) 'template_id': templateId,
    });
    return DailyReport.fromJson(response.data);
  }

  /// 리포트 섹션 내용 업데이트
  Future<DailyReport> updateReport(
    String id,
    List<Map<String, String?>> sections,
  ) async {
    final response = await _dio.put('/app/my/daily-reports/$id', data: {
      'sections': sections,
    });
    return DailyReport.fromJson(response.data);
  }

  /// 리포트 제출 (draft → submitted)
  Future<DailyReport> submitReport(String id) async {
    final response = await _dio.post('/app/my/daily-reports/$id/submit');
    return DailyReport.fromJson(response.data);
  }
}
