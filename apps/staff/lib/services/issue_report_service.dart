/// Issue Report API 서비스 — /app/my/reports?type=issue
///
/// 이슈 리포트 작성/조회/상태 전이/댓글.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue_report.dart';
import 'api_client.dart';

final issueReportServiceProvider = Provider<IssueReportService>((ref) {
  return IssueReportService(ref.read(dioProvider));
});

class IssueReportService {
  final Dio _dio;
  IssueReportService(this._dio);

  /// 매장별 issue form template (categories + custom fields) lookup.
  Future<IssueReportTemplate> getTemplate({String? storeId}) async {
    final params = <String, dynamic>{'type': 'issue'};
    if (storeId != null) params['store_id'] = storeId;
    final res = await _dio.get(
      '/app/my/reports/template',
      queryParameters: params,
    );
    return IssueReportTemplate.fromJson(res.data);
  }

  /// 내가 볼 수 있는 이슈 리포트 목록.
  /// only_mine=false면 visibility 기반 (매장 SV+ 또는 extra_viewer)
  Future<({List<IssueReport> items, int total})> listReports({
    String? storeId,
    String? status,
    bool onlyMine = false,
    bool showAll = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'type': 'issue',
      'page': page,
      'per_page': perPage,
      'only_mine': onlyMine,
      'show_all': showAll,
    };
    if (storeId != null) params['store_id'] = storeId;
    if (status != null) params['status'] = status;
    final res = await _dio.get('/app/my/reports', queryParameters: params);
    final list = (res.data['items'] as List?) ?? [];
    return (
      items: list.map((e) => IssueReport.fromJson(e)).toList(),
      total: res.data['total'] as int? ?? list.length,
    );
  }

  Future<IssueReport> getReport(String id) async {
    final res = await _dio.get('/app/my/reports/$id');
    return IssueReport.fromJson(res.data);
  }

  /// 이슈 리포트 생성.
  ///
  /// [links] 는 schedule_ids / checklist_instance_ids / position_ids /
  /// work_role_ids / related_user_ids 를 담을 수 있다. 모두 옵션.
  Future<IssueReport> createReport({
    required String storeId,
    required String title,
    required String category,
    required String severity,
    String? description,
    List<IssueAttachment> attachments = const [],
    Map<String, dynamic> customFieldValues = const {},
    List<String> extraViewerUserIds = const [],
    Map<String, List<String>> links = const {},
  }) async {
    final res = await _dio.post('/app/my/reports', data: {
      'type': 'issue',
      'store_id': storeId,
      'title': title,
      'payload': {
        'category': category,
        'severity': severity,
        if (description != null) 'description': description,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'extra_viewers': {'user_ids': extraViewerUserIds},
        'custom_field_values': customFieldValues,
        'links': {
          'schedule_ids': links['schedule_ids'] ?? const <String>[],
          'checklist_instance_ids':
              links['checklist_instance_ids'] ?? const <String>[],
          'position_ids': links['position_ids'] ?? const <String>[],
          'work_role_ids': links['work_role_ids'] ?? const <String>[],
          'related_user_ids': links['related_user_ids'] ?? const <String>[],
        },
      },
    });
    return IssueReport.fromJson(res.data);
  }

  /// 상태 전이 (open → in_progress → closed).
  Future<IssueReport> transition(String id, String newStatus) async {
    final res = await _dio.post(
      '/app/my/reports/$id/transition',
      data: {'status': newStatus},
    );
    return IssueReport.fromJson(res.data);
  }

  Future<void> addComment(String id, String content) async {
    await _dio.post('/app/my/reports/$id/comments', data: {'content': content});
  }

  Future<void> deleteReport(String id) async {
    await _dio.delete('/app/my/reports/$id');
  }

  /// LinkPicker용 매장별 5종 옵션 (schedules / checklist_instances /
  /// positions / work_roles / users) 한 번에 조회.
  Future<Map<String, dynamic>> getLinkOptions(String storeId) async {
    final res = await _dio.get('/app/my/stores/$storeId/link-options');
    return (res.data as Map).cast<String, dynamic>();
  }
}
