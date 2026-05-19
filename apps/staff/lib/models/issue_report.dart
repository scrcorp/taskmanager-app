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

  const IssueCategoryDef({
    required this.code,
    required this.label,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory IssueCategoryDef.fromJson(Map<String, dynamic> j) => IssueCategoryDef(
        code: j['code'] ?? '',
        label: j['label'] ?? j['code'] ?? '',
        color: j['color'],
        sortOrder: j['sort_order'] ?? 0,
        isActive: j['is_active'] ?? true,
      );
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
      linkedIssueId: payload['linked_issue_id'],
      links: _parseLinks(payload['links']),
      commentCount: j['comment_count'] ?? 0,
      comments: cmts.map((e) => IssueReportComment.fromJson(e)).toList(),
    );
  }
}
