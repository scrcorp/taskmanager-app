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
    String visibilityScope = IssueVisibilityScope.defaultScope,
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
        // 확대 전용 조회 범위. legacy share_with_store_all 은 더 이상 보내지 않는다.
        'visibility_scope': visibilityScope,
        // notify_excluded_user_ids 는 보내지 않는다 — 자동 수신자(매장 GM+)는
        // 해제 불가라 서버가 이 키를 무시한다(하위호환으로 받기만 함).
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

  /// 알림 수신자 조회.
  ///
  /// - [storeId] 만 주면 그 매장 자동 후보(source=auto, is_recipient=true).
  /// - [reportId] 를 주면 그 리포트 기준 최종 수신자(자동 − 제외 + 추가).
  ///   이 경우 [storeId] 는 생략 가능하며, 둘 다 주고 서로 다르면 서버가 400.
  Future<IssueRecipientsResponse> getIssueRecipients({
    String? storeId,
    String? reportId,
  }) async {
    final params = <String, dynamic>{};
    if (storeId != null) params['store_id'] = storeId;
    if (reportId != null) params['report_id'] = reportId;
    final res = await _dio.get(
      '/app/my/reports/issue-recipients',
      queryParameters: params,
    );
    return IssueRecipientsResponse.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// 조회 범위(scope) 별 "실제로 보게 될 사람" 예상 목록.
  ///
  /// 계약(server 와 공유, console 과 동일 응답):
  ///   GET /app/my/reports/issue-viewers?store_id=&scope=[&report_id=]
  ///   → { store_id, report_id, scope, mode: "list"|"summary",
  ///       summary: {label, count},
  ///       items: [{user_id, full_name, role_label, role_priority,
  ///                reason, reason_label, is_notified}] }
  ///   store_all 은 인원이 많아 mode="summary" + summary.count 만 온다.
  ///
  /// NOTE: 실패 시 issue-recipients 로 되짚지 않는다. 그쪽은 **알림 수신자**라
  /// scope 를 무시하므로, 조용히 다른 의미의 목록을 "예상 조회자"로 보여주게 된다.
  Future<IssueViewersPreview> getIssueViewers({
    required String storeId,
    required String scope,
    String? reportId,
  }) async {
    final params = <String, dynamic>{'store_id': storeId, 'scope': scope};
    if (reportId != null) params['report_id'] = reportId;

    final res = await _dio.get(
      '/app/my/reports/issue-viewers',
      queryParameters: params,
    );
    final data = res.data;
    if (data is! Map) return IssueViewersPreview(scope: scope);
    return IssueViewersPreview.fromJson(
      data.cast<String, dynamic>(),
      requestedScope: scope,
    );
  }

  /// LinkPicker용 매장별 5종 옵션 (schedules / checklist_instances /
  /// positions / work_roles / users) 한 번에 조회.
  Future<Map<String, dynamic>> getLinkOptions(String storeId) async {
    final res = await _dio.get('/app/my/stores/$storeId/link-options');
    return (res.data as Map).cast<String, dynamic>();
  }
}
