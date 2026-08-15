/// Issue Report 데이터 모델 (multi-type Report의 issue 타입).
///
/// Staff/SV/GM/Owner 모두 작성 가능. 매장 운영 중 발생한 issue를 즉시 신고.
/// 상태: open → in_progress → closed

class IssueAttachment {
  final String? key;
  final String? url;
  final String? mimeType;
  final String? kind; // "image" | "video"
  final String? name;
  final int? size;

  const IssueAttachment({
    this.key,
    this.url,
    this.mimeType,
    this.kind,
    this.name,
    this.size,
  });

  factory IssueAttachment.fromJson(Map<String, dynamic> j) => IssueAttachment(
        key: j['key'],
        url: j['url'],
        mimeType: j['mime_type'],
        kind: j['kind'],
        name: j['name'],
        size: j['size'],
      );

  Map<String, dynamic> toJson() => {
        if (key != null) 'key': key,
        if (mimeType != null) 'mime_type': mimeType,
        if (kind != null) 'kind': kind,
        if (name != null) 'name': name,
        if (size != null) 'size': size,
      };
}

class IssueCategoryDef {
  final String code;
  final String label;
  final String? color;
  final int sortOrder;
  final bool isActive;

  /// 카테고리를 고르면 description 에 프리필할 제목 줄 원문.
  /// 키가 없거나 null 이면 프리셋 없음 (기존 템플릿 하위호환).
  final String? descriptionTemplate;

  const IssueCategoryDef({
    required this.code,
    required this.label,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.descriptionTemplate,
  });

  factory IssueCategoryDef.fromJson(Map<String, dynamic> j) => IssueCategoryDef(
        code: j['code'] ?? '',
        label: j['label'] ?? j['code'] ?? '',
        color: j['color'],
        sortOrder: j['sort_order'] ?? 0,
        isActive: j['is_active'] ?? true,
        descriptionTemplate: j['description_template'] as String?,
      );
}

/// issue payload.visibility_scope — 확대 전용 조회 범위.
class IssueVisibilityScope {
  static const String defaultScope = 'default';
  static const String managers = 'managers';
  static const String storeAll = 'store_all';

  static const List<String> all = [defaultScope, managers, storeAll];

  /// 서버 payload 정규화. 알 수 없는 값/누락은 default,
  /// legacy share_with_store_all=true 는 store_all 로 읽는다.
  static String fromPayload(Map<String, dynamic> payload) {
    final raw = payload['visibility_scope'];
    if (raw is String && all.contains(raw)) return raw;
    final legacy = payload['share_with_store_all'];
    if (legacy == true || legacy == 'true') return storeAll;
    return defaultScope;
  }
}

/// GET /app/my/reports/issue-recipients 응답 항목.
class IssueRecipient {
  final String userId;
  final String fullName;

  /// DB 의 role name 원문(owner / general_manager / supervisor / staff / 커스텀).
  final String roleLabel;
  final int rolePriority;

  /// "auto" (자동 후보) | "added" (extra_viewers 로 지목)
  final String source;

  /// 현재 알림을 받는지. 자동 수신자는 해제 불가라 항상 true 다
  /// (과거 리포트에서만 false 가 올 수 있다).
  final bool isRecipient;

  const IssueRecipient({
    required this.userId,
    required this.fullName,
    required this.roleLabel,
    required this.rolePriority,
    required this.source,
    required this.isRecipient,
  });

  bool get isAdded => source == 'added';

  factory IssueRecipient.fromJson(Map<String, dynamic> j) => IssueRecipient(
        userId: j['user_id'] ?? '',
        fullName: (j['full_name'] as String?) ?? '',
        roleLabel: (j['role_label'] as String?) ?? '',
        rolePriority: j['role_priority'] ?? 0,
        source: (j['source'] as String?) ?? 'auto',
        isRecipient: j['is_recipient'] ?? true,
      );
}

class IssueRecipientsResponse {
  final String? storeId;
  final String? reportId;
  final List<IssueRecipient> items;

  const IssueRecipientsResponse({
    this.storeId,
    this.reportId,
    this.items = const [],
  });

  factory IssueRecipientsResponse.fromJson(Map<String, dynamic> j) =>
      IssueRecipientsResponse(
        storeId: j['store_id'] as String?,
        reportId: j['report_id'] as String?,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => IssueRecipient.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// 조회 범위(scope) 별 "이 리포트를 보게 될 사람" 예상 목록의 한 항목.
///
/// 서버 계약(IssueExpectedViewerItem):
///   { user_id, full_name, role_label, role_priority,
///     reason, reason_label, is_notified }
///
/// [reason] 은 왜 포함됐는지의 **코드**다:
///   "author" | "gm_or_above" | "store_manager" | "added".
/// [reasonLabel] 은 서버가 만들어 준 영어 문구로, 클라가 모르는 새 reason 코드가
/// 와도 아무 말이나 찍지 않도록 하는 fallback 이다 (모르는 코드를 "manager" 로
/// 뭉개면 작성자 본인/추가 지목까지 매니저라고 거짓 표시된다).
class IssueViewer {
  final String userId;
  final String fullName;
  final String roleLabel;
  final int rolePriority;
  final String reason;
  final String reasonLabel;

  /// 조회권만이 아니라 알림까지 받는가.
  final bool isNotified;

  const IssueViewer({
    required this.userId,
    required this.fullName,
    this.roleLabel = '',
    this.rolePriority = 0,
    this.reason = '',
    this.reasonLabel = '',
    this.isNotified = false,
  });

  factory IssueViewer.fromJson(Map<String, dynamic> j) => IssueViewer(
        userId: (j['user_id'] as String?) ?? '',
        fullName: (j['full_name'] as String?) ?? '',
        roleLabel: (j['role_label'] as String?) ?? '',
        rolePriority: (j['role_priority'] as num?)?.toInt() ?? 0,
        reason: (j['reason'] as String?) ?? '',
        reasonLabel: (j['reason_label'] as String?) ?? '',
        isNotified: j['is_notified'] == true,
      );
}

/// scope 별 예상 조회자 응답.
///
/// 서버 계약(IssueExpectedViewersResponse):
///   { store_id, report_id, scope, mode: "list"|"summary",
///     summary: { label, count }, items: [...] }
///
/// store_all 처럼 인원이 많은 범위는 mode="summary" 로 목록 없이 개수만 온다.
/// 그 경우 [listed] 가 false 이고 [totalCount] 만 의미가 있다.
class IssueViewersPreview {
  final String scope;
  final List<IssueViewer> items;

  /// 목록을 그릴 수 있는 응답인지(mode=="list"). false 면 요약 문구만 보여준다.
  final bool listed;

  /// 서버가 알려준 총 인원(summary.count).
  final int? totalCount;

  const IssueViewersPreview({
    this.scope = IssueVisibilityScope.defaultScope,
    this.items = const [],
    this.listed = true,
    this.totalCount,
  });

  factory IssueViewersPreview.fromJson(
    Map<String, dynamic> j, {
    String? requestedScope,
  }) {
    final items = ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => IssueViewer.fromJson(e.cast<String, dynamic>()))
        .where((v) => v.userId.isNotEmpty)
        .toList();

    final scope = (j['scope'] as String?) ??
        requestedScope ??
        IssueVisibilityScope.defaultScope;

    final summary = (j['summary'] as Map?)?.cast<String, dynamic>();
    final count = (summary?['count'] as num?)?.toInt();

    // mode 가 없으면(구버전 서버) 목록 응답으로 본다.
    final listed = (j['mode'] as String?) != 'summary';

    return IssueViewersPreview(
      scope: scope,
      items: items,
      listed: listed,
      totalCount: count ?? (listed ? items.length : null),
    );
  }
}

class IssueCustomFieldDef {
  final String type; // short_text | long_text | number | single_choice | multi_choice
  final String id;
  final String label;
  final bool required;
  final String? placeholder;
  final List<String>? options;
  final int? maxLength;
  final int sortOrder;

  const IssueCustomFieldDef({
    required this.type,
    required this.id,
    required this.label,
    this.required = false,
    this.placeholder,
    this.options,
    this.maxLength,
    this.sortOrder = 0,
  });

  factory IssueCustomFieldDef.fromJson(Map<String, dynamic> j) => IssueCustomFieldDef(
        type: j['type'] ?? 'short_text',
        id: j['id'] ?? '',
        label: j['label'] ?? '',
        required: j['required'] ?? false,
        placeholder: j['placeholder'],
        options: (j['options'] as List?)?.cast<String>(),
        maxLength: j['max_length'],
        sortOrder: j['sort_order'] ?? 0,
      );
}

class IssueReportTemplate {
  final String id;
  final String name;
  final List<IssueCategoryDef> categories;
  final List<IssueCustomFieldDef> customFields;

  const IssueReportTemplate({
    required this.id,
    required this.name,
    this.categories = const [],
    this.customFields = const [],
  });

  factory IssueReportTemplate.fromJson(Map<String, dynamic> j) {
    final payload = (j['payload'] ?? {}) as Map<String, dynamic>;
    return IssueReportTemplate(
      id: j['id'] ?? '',
      name: j['name'] ?? 'Issue Form',
      categories: ((payload['categories'] as List?) ?? [])
          .map((e) => IssueCategoryDef.fromJson(e))
          .toList(),
      customFields: ((payload['custom_fields'] as List?) ?? [])
          .map((e) => IssueCustomFieldDef.fromJson(e))
          .toList(),
    );
  }
}

class IssueReportComment {
  final String id;
  final String? userId;
  final String? userName;
  final String content;
  final DateTime createdAt;

  const IssueReportComment({
    required this.id,
    this.userId,
    this.userName,
    required this.content,
    required this.createdAt,
  });

  factory IssueReportComment.fromJson(Map<String, dynamic> j) => IssueReportComment(
        id: j['id'],
        userId: j['user_id'],
        userName: j['user_name'],
        content: j['content'] ?? '',
        createdAt: DateTime.parse(j['created_at']),
      );
}

Map<String, List<String>> _parseLinks(dynamic raw) {
  if (raw is! Map) return const {};
  const keys = [
    'schedule_ids',
    'checklist_instance_ids',
    'position_ids',
    'work_role_ids',
    'related_user_ids',
  ];
  final out = <String, List<String>>{};
  for (final k in keys) {
    final v = raw[k];
    if (v is List) {
      out[k] = v.whereType<String>().toList();
    }
  }
  return out;
}

class IssueReport {
  final String id;
  final String type; // "issue"
  final String organizationId;
  final String? storeId;
  final String? storeName;
  final String? templateId;
  final String? authorId;
  final String? authorName;
  final String? title;
  final String status; // open | in_progress | closed
  final DateTime? reportDate;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  // payload
  final String? category;
  final String? severity; // low | medium | high | critical
  final String? description;
  final List<IssueAttachment> attachments;
  final Map<String, dynamic> customFieldValues;
  final List<String> extraViewerUserIds;

  /// "default" | "managers" | "store_all". 키가 없으면 "default".
  final String visibilityScope;

  /// @deprecated 자동 수신자(매장 GM+)는 해제 불가로 바뀌어 이 값은 더 이상
  /// 적용되지 않는다. 과거 리포트 payload 하위호환용으로 읽기만 한다.
  final List<String> notifyExcludedUserIds;
  final String? linkedIssueId;
  /// 관련 리소스 ID 묶음. key: schedule_ids / checklist_instance_ids /
  /// position_ids / work_role_ids / related_user_ids. console에서 입력된 값을
  /// staff app에서도 동일하게 볼 수 있도록 그대로 보관.
  final Map<String, List<String>> links;
  final int commentCount;
  final List<IssueReportComment> comments;

  const IssueReport({
    required this.id,
    required this.type,
    required this.organizationId,
    this.storeId,
    this.storeName,
    this.templateId,
    this.authorId,
    this.authorName,
    this.title,
    required this.status,
    this.reportDate,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.severity,
    this.description,
    this.attachments = const [],
    this.customFieldValues = const {},
    this.extraViewerUserIds = const [],
    this.visibilityScope = IssueVisibilityScope.defaultScope,
    this.notifyExcludedUserIds = const [],
    this.linkedIssueId,
    this.links = const {},
    this.commentCount = 0,
    this.comments = const [],
  });

  factory IssueReport.fromJson(Map<String, dynamic> j) {
    final payload = (j['payload'] ?? {}) as Map<String, dynamic>;
    final atts = (payload['attachments'] as List?) ?? [];
    final extraViewers = (payload['extra_viewers'] as Map?) ?? {};
    final cmts = (j['comments'] as List?) ?? [];
    return IssueReport(
      id: j['id'],
      type: j['type'] ?? 'issue',
      organizationId: j['organization_id'] ?? '',
      storeId: j['store_id'],
      storeName: j['store_name'],
      templateId: j['template_id'],
      authorId: j['author_id'],
      authorName: j['author_name'],
      title: j['title'],
      status: j['status'] ?? 'open',
      reportDate: j['report_date'] != null
          ? DateTime.tryParse(j['report_date'].toString())
          : null,
      submittedAt: j['submitted_at'] != null
          ? DateTime.tryParse(j['submitted_at'].toString())
          : null,
      createdAt: DateTime.parse(j['created_at']),
      updatedAt: DateTime.parse(j['updated_at']),
      category: payload['category'],
      severity: payload['severity'],
      description: payload['description'],
      attachments: atts.map((e) => IssueAttachment.fromJson(e)).toList(),
      customFieldValues:
          (payload['custom_field_values'] as Map?)?.cast<String, dynamic>() ?? {},
      extraViewerUserIds:
          ((extraViewers['user_ids'] as List?) ?? []).cast<String>(),
      visibilityScope: IssueVisibilityScope.fromPayload(payload),
      notifyExcludedUserIds:
          ((payload['notify_excluded_user_ids'] as List?) ?? const [])
              .whereType<String>()
              .toList(),
      linkedIssueId: payload['linked_issue_id'],
      links: _parseLinks(payload['links']),
      commentCount: j['comment_count'] ?? 0,
      comments: cmts.map((e) => IssueReportComment.fromJson(e)).toList(),
    );
  }
}
