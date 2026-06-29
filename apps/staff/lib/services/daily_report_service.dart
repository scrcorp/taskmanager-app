/// Daily Report API 서비스 (통합 reports 엔드포인트)
///
/// 일일 리포트 템플릿/타입 조회, 리포트 CRUD, 제출/검토/읽음확인 API.
/// 엔드포인트: /app/my/reports/* (type=daily)
library;

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
    final params = <String, dynamic>{'type': 'daily'};
    if (storeId != null) params['store_id'] = storeId;

    final response = await _dio.get(
      '/app/my/reports/template',
      queryParameters: params,
    );
    return DailyReportTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  /// 매장에 활성화된 report type(period) 목록 — period 선택지 채우기용
  Future<List<EffectiveReportType>> getReportTypes({
    String? storeId,
    bool activeOnly = true,
  }) async {
    final params = <String, dynamic>{'active_only': activeOnly};
    if (storeId != null) params['store_id'] = storeId;

    final response = await _dio.get(
      '/app/my/reports/report-types',
      queryParameters: params,
    );
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .map((e) => EffectiveReportType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내 리포트 목록 조회 — 페이지네이션 + 필터
  Future<({List<DailyReport> items, int total})> getMyReports({
    String? storeId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? period,
    bool onlyMine = true,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'type': 'daily',
      'only_mine': onlyMine,
      'page': page,
      'per_page': perPage,
    };
    if (storeId != null) params['store_id'] = storeId;
    if (status != null) params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (period != null) params['period'] = period;

    final response = await _dio.get(
      '/app/my/reports',
      queryParameters: params,
    );
    final data = response.data;
    final list = data['items'] as List? ?? [];
    return (
      items: list
          .map((e) => DailyReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? list.length,
    );
  }

  /// 리포트 상세 조회 — 섹션 + 댓글 + 읽음확인 포함
  Future<DailyReport> getReport(String id) async {
    final response = await _dio.get('/app/my/reports/$id');
    return DailyReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// 리포트 생성 — 빈 draft 리포트 생성 (템플릿 섹션 자동 복사)
  ///
  /// period 는 payload 안으로 들어간다 (통합 스키마).
  Future<DailyReport> createReport({
    required String storeId,
    required String reportDate,
    required String period,
    String? templateId,
  }) async {
    final response = await _dio.post('/app/my/reports', data: {
      'type': 'daily',
      'store_id': storeId,
      'report_date': reportDate,
      if (templateId != null) 'template_id': templateId,
      'payload': {'period': period},
    });
    return DailyReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// 리포트 섹션 내용 업데이트 — sort_order 기반
  Future<DailyReport> updateReport(
    String id,
    List<Map<String, dynamic>> sections,
  ) async {
    final response = await _dio.put('/app/my/reports/$id', data: {
      'sections': sections,
    });
    return DailyReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// 리포트 삭제 (draft만 가능)
  Future<void> deleteReport(String id) async {
    await _dio.delete('/app/my/reports/$id');
  }

  /// 리포트 제출 (draft → submitted)
  Future<DailyReport> submitReport(String id) async {
    final response = await _dio.post('/app/my/reports/$id/submit');
    return DailyReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// 리포트 읽음 확인 (멱등) — SV가 리포트를 읽고 확인
  Future<DailyReport> acknowledgeReport(String id) async {
    final response = await _dio.post('/app/my/reports/$id/acknowledge');
    return DailyReport.fromJson(response.data as Map<String, dynamic>);
  }
}
