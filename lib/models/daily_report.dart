/// Daily Report 데이터 모델
///
/// SV(Supervisor) 이상이 작성하는 일일 리포트.
/// 템플릿 기반 섹션 구조 + 댓글을 지원한다.
/// 상태: draft → submitted → reviewed

/// 일일 리포트 템플릿 섹션
class DailyReportTemplateSection {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final bool isRequired;

  const DailyReportTemplateSection({
    required this.id,
    required this.title,
    this.description,
    required this.sortOrder,
    required this.isRequired,
  });

  factory DailyReportTemplateSection.fromJson(Map<String, dynamic> json) {
    return DailyReportTemplateSection(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      sortOrder: json['sort_order'] ?? 0,
      isRequired: json['is_required'] ?? false,
    );
  }
}

/// 일일 리포트 템플릿
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
    return DailyReportTemplate(
      id: json['id'],
      name: json['name'],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => DailyReportTemplateSection.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 일일 리포트 섹션 (작성된 내용 포함)
class DailyReportSection {
  final String id;
  final String? templateSectionId;
  final String title;
  final String? content;
  final int sortOrder;

  const DailyReportSection({
    required this.id,
    this.templateSectionId,
    required this.title,
    this.content,
    required this.sortOrder,
  });

  factory DailyReportSection.fromJson(Map<String, dynamic> json) {
    return DailyReportSection(
      id: json['id'],
      templateSectionId: json['template_section_id'],
      title: json['title'],
      content: json['content'],
      sortOrder: json['sort_order'] ?? 0,
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
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// 일일 리포트 본체
class DailyReport {
  final String id;
  final String? organizationId;
  final String storeId;
  final String? storeName;
  final String? templateId;
  final String authorId;
  final String? authorName;
  final DateTime reportDate;
  /// 시간대: 'lunch' 또는 'dinner'
  final String period;
  /// 상태: 'draft', 'submitted', 'reviewed'
  final String status;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DailyReportSection> sections;
  final List<DailyReportComment> comments;
  final int commentCount;

  const DailyReport({
    required this.id,
    this.organizationId,
    required this.storeId,
    this.storeName,
    this.templateId,
    required this.authorId,
    this.authorName,
    required this.reportDate,
    required this.period,
    required this.status,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
    this.sections = const [],
    this.comments = const [],
    this.commentCount = 0,
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

  /// 시간대 표시 라벨
  String get periodLabel {
    switch (period) {
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return period;
    }
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      id: json['id'],
      organizationId: json['organization_id'],
      storeId: json['store_id'],
      storeName: json['store_name'],
      templateId: json['template_id'],
      authorId: json['author_id'],
      authorName: json['author_name'],
      reportDate: DateTime.parse(json['report_date']),
      period: json['period'] ?? 'lunch',
      status: json['status'] ?? 'draft',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => DailyReportSection.fromJson(e))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => DailyReportComment.fromJson(e))
              .toList() ??
          [],
      commentCount: json['comment_count'] ?? 0,
    );
  }
}
