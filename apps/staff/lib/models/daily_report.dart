/// Daily Report 데이터 모델 (통합 reports 엔드포인트 기반)
///
/// SV(Supervisor) 이상이 작성하는 일일 리포트.
/// 통합 /app/my/reports (type=daily) 엔드포인트 응답을 파싱한다.
/// period/sections 는 payload 안에 중첩되어 들어온다.
/// 상태: draft → submitted → reviewed
library;

/// 매장에 적용되는 effective report type (period 선택지).
///
/// /app/my/reports/report-types 응답. lunch/dinner 기본 활성,
/// morning 등은 매장 설정에 따라 활성/비활성.
class EffectiveReportType {
  final String code;
  final String label;
  final int sortOrder;
  final bool isActive;
  final String? defaultDeadlineLocalTime;
  final int deadlineDayOffset;
  final String scope; // "org" | "store"
  final String? id;
  final String? orgTypeId;

  const EffectiveReportType({
    required this.code,
    required this.label,
    this.sortOrder = 0,
    this.isActive = true,
    this.defaultDeadlineLocalTime,
    this.deadlineDayOffset = 0,
    this.scope = 'org',
    this.id,
    this.orgTypeId,
  });

  factory EffectiveReportType.fromJson(Map<String, dynamic> json) {
    return EffectiveReportType(
      code: json['code'] as String,
      label: json['label'] as String? ?? json['code'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      defaultDeadlineLocalTime: json['default_deadline_local_time'] as String?,
      deadlineDayOffset: json['deadline_day_offset'] as int? ?? 0,
      scope: json['scope'] as String? ?? 'org',
      id: json['id'] as String?,
      orgTypeId: json['org_type_id'] as String?,
    );
  }
}

/// 일일 리포트 템플릿 섹션 (template payload.sections).
class DailyReportTemplateSection {
  final String? id;
  final String title;
  final String? description;
  final int sortOrder;
  final bool isRequired;

  const DailyReportTemplateSection({
    this.id,
    required this.title,
    this.description,
    required this.sortOrder,
    required this.isRequired,
  });

  factory DailyReportTemplateSection.fromJson(Map<String, dynamic> json) {
    return DailyReportTemplateSection(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isRequired: json['is_required'] as bool? ?? false,
    );
  }
}

/// 일일 리포트 템플릿. sections 는 payload 안에 들어온다.
class DailyReportTemplate {
  final String id;
  final String name;
  final List<DailyReportTemplateSection> sections;

  const DailyReportTemplate({
    required this.id,
    required this.name,
    this.sections = const [],
  });

  factory DailyReportTemplate.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? const {};
    final rawSections = payload['sections'] as List<dynamic>?;
    return DailyReportTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sections: rawSections
              ?.map((e) =>
                  DailyReportTemplateSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// 일일 리포트 섹션 (report payload.sections, sortOrder로 식별).
///
/// 통합 payload 의 섹션은 description/is_required 를 보존하지 않으므로,
/// 화면에서 템플릿(template_section_id / sort_order 매칭)으로 보강한다.
class DailyReportSection {
  final String? id;
  final String title;
  final String? content;
  final int sortOrder;
  final String? templateSectionId;
  // 템플릿에서 보강되는 메타 (payload 에는 없음, 화면에서 채움).
  final String? description;
  final bool isRequired;

  const DailyReportSection({
    this.id,
    required this.title,
    this.content,
    required this.sortOrder,
    this.templateSectionId,
    this.description,
    this.isRequired = false,
  });

  /// sortOrder를 문자열 키로 사용
  String get key => sortOrder.toString();

  DailyReportSection copyWith({
    String? description,
    bool? isRequired,
  }) {
    return DailyReportSection(
      id: id,
      title: title,
      content: content,
      sortOrder: sortOrder,
      templateSectionId: templateSectionId,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  factory DailyReportSection.fromJson(Map<String, dynamic> json) {
    return DailyReportSection(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      templateSectionId: json['template_section_id'] as String?,
      description: json['description'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
    );
  }
}

/// 일일 리포트 댓글
class DailyReportComment {
  final String id;
  final String userId;
  final String? userName;
  final String content;
  final DateTime createdAt;

  const DailyReportComment({
    required this.id,
    required this.userId,
    this.userName,
    required this.content,
    required this.createdAt,
  });

  factory DailyReportComment.fromJson(Map<String, dynamic> json) {
    return DailyReportComment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 일일 리포트 읽음 확인(acknowledgement).
class DailyReportAcknowledgement {
  final String userId;
  final String? userName;
  final DateTime acknowledgedAt;

  const DailyReportAcknowledgement({
    required this.userId,
    this.userName,
    required this.acknowledgedAt,
  });

  factory DailyReportAcknowledgement.fromJson(Map<String, dynamic> json) {
    return DailyReportAcknowledgement(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      acknowledgedAt: DateTime.parse(json['acknowledged_at'] as String),
    );
  }
}

/// 일일 리포트 본체
class DailyReport {
  final String id;
  final String type;
  final String? organizationId;
  final String storeId;
  final String? storeName;
  final String? templateId;
  final String authorId;
  final String? authorName;
  final String? title;
  final DateTime reportDate;

  /// 시간대 코드 (payload.period). 'lunch' / 'dinner' / 'morning' / 커스텀
  final String period;

  /// 상태: 'draft', 'submitted', 'reviewed'
  final String status;
  final DateTime? submittedAt;

  // 마감 관련 (display only)
  final DateTime? deadlineAt;
  final bool isOverdue;
  final bool isLate;

  // 검토 상태
  final String? reviewedById;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DailyReportSection> sections;
  final List<DailyReportComment> comments;
  final int commentCount;
  final List<DailyReportAcknowledgement> acknowledgements;
  final int acknowledgementCount;

  const DailyReport({
    required this.id,
    this.type = 'daily',
    this.organizationId,
    required this.storeId,
    this.storeName,
    this.templateId,
    required this.authorId,
    this.authorName,
    this.title,
    required this.reportDate,
    required this.period,
    required this.status,
    this.submittedAt,
    this.deadlineAt,
    this.isOverdue = false,
    this.isLate = false,
    this.reviewedById,
    this.reviewedByName,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.sections = const [],
    this.comments = const [],
    this.commentCount = 0,
    this.acknowledgements = const [],
    this.acknowledgementCount = 0,
  });

  /// 상태 표시 라벨
  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'reviewed':
        return 'Reviewed';
      default:
        return status;
    }
  }

  /// 시간대 표시 라벨. 알려진 코드는 영어 라벨, 그 외엔 코드를 title-case.
  String get periodLabel {
    switch (period) {
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'morning':
        return 'Morning';
      default:
        if (period.isEmpty) return period;
        return period[0].toUpperCase() + period.substring(1);
    }
  }

  /// 현재 사용자가 이미 읽음 확인했는지
  bool acknowledgedBy(String userId) =>
      acknowledgements.any((a) => a.userId == userId);

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? const {};
    final rawSections = payload['sections'] as List<dynamic>?;
    return DailyReport(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'daily',
      organizationId: json['organization_id'] as String?,
      storeId: json['store_id'] as String,
      storeName: json['store_name'] as String?,
      templateId: json['template_id'] as String?,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String?,
      title: json['title'] as String?,
      reportDate: DateTime.parse(json['report_date'] as String),
      period: payload['period'] as String? ?? 'lunch',
      status: json['status'] as String? ?? 'draft',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      deadlineAt: json['deadline_at'] != null
          ? DateTime.parse(json['deadline_at'] as String)
          : null,
      isOverdue: json['is_overdue'] as bool? ?? false,
      isLate: json['is_late'] as bool? ?? false,
      reviewedById: json['reviewed_by_id'] as String?,
      reviewedByName: json['reviewed_by_name'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sections: rawSections
              ?.map((e) => DailyReportSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => DailyReportComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      commentCount: json['comment_count'] as int? ?? 0,
      acknowledgements: (json['acknowledgements'] as List<dynamic>?)
              ?.map((e) =>
                  DailyReportAcknowledgement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      acknowledgementCount: json['acknowledgement_count'] as int? ?? 0,
    );
  }
}
