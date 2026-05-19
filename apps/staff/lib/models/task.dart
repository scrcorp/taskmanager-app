/// Task (work item) 데이터 모델 — staff app 용.
///
/// 명명 변경 이력: additional_tasks → issues → tasks. 클래스 이름은 기존
/// 호출처 호환 위해 `AdditionalTask` 그대로 유지 (alias 성격).
import 'store.dart';

class AdditionalTask {
  final String id;
  final String? storeId;
  final String? storeName;
  final Store? store;
  final String title;
  final String? description;

  /// 우선순위: 'urgent' / 'normal' (신규 task 시스템은 두 단계만).
  final String priority;

  /// 상태: 'pending' / 'in_progress' / 'completed'.
  final String status;

  final String? severity;
  final String? category;
  final DateTime? dueDate;
  final String? createdByName;

  /// 담당자 목록 — { user_id, user_name }.
  final List<TaskAssignee> assignees;

  /// 관리자가 task 설명용으로 첨부한 사진/영상/파일.
  final List<TaskAttachmentItem> attachments;

  /// store scope (multi-store / org-wide 지원).
  final List<String> storeIds;
  final List<String> storeNames;

  /// review 시점 정보.
  final DateTime? submittedAt;
  final String? submittedByName;
  final DateTime? reviewedAt;
  final String? reviewedByName;

  final String? sourceReportId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdditionalTask({
    required this.id,
    this.storeId,
    this.storeName,
    this.store,
    required this.title,
    this.description,
    this.priority = 'normal',
    this.status = 'pending',
    this.severity,
    this.category,
    this.dueDate,
    this.createdByName,
    this.assignees = const [],
    this.attachments = const [],
    this.storeIds = const [],
    this.storeNames = const [],
    this.submittedAt,
    this.submittedByName,
    this.reviewedAt,
    this.reviewedByName,
    this.sourceReportId,
    this.createdAt,
    this.updatedAt,
  });

  String get priorityLabel {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'normal':
        return 'Normal';
      default:
        return priority;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'under_review':
        return 'Under review';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  /// 호환용 alias — 기존 UI 가 `assigneeNames` 으로 라벨 렌더링하던 코드 보존.
  List<String> get assigneeNames =>
      assignees.map((a) => a.fullName ?? '').where((s) => s.isNotEmpty).toList();

  // ── 신규 task 시스템에 없는 옛 필드들 — UI 호환 위해 null/empty 기본값 ──
  /// 신규 시스템엔 없음.
  List<String> get labels => const [];

  /// 신규 시스템엔 task-level completedAt 없음. (per-assignee 도 사라짐.)
  DateTime? get completedAt => null;

  /// 신규 시스템엔 없음.
  String? get completedByName => null;

  /// 신규 시스템엔 없음 (start_date 컬럼 자체가 없음).
  DateTime? get startDate => null;

  factory AdditionalTask.fromJson(Map<String, dynamic> json) {
    return AdditionalTask(
      id: json['id'],
      storeId: json['store_id'],
      storeName: json['store_name'],
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      title: json['title'],
      description: json['description'],
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'pending',
      severity: json['severity'],
      category: json['category'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdByName: json['created_by_name'],
      assignees: (json['assignees'] as List<dynamic>?)
              ?.map((e) => TaskAssignee.fromJson(e))
              .toList() ??
          [],
      attachments: ((json['attachments'] as List?) ?? [])
          .map((e) => TaskAttachmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeIds: ((json['store_ids'] as List?) ?? []).cast<String>(),
      storeNames: ((json['store_names'] as List?) ?? []).cast<String>(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      submittedByName: json['submitted_by_name'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      reviewedByName: json['reviewed_by_name'] as String?,
      sourceReportId: json['source_report_id'] as String?,
      createdAt:
          json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt:
          json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}

/// Task attachment — server 가 resolve_url 처리한 url 포함.
class TaskAttachmentItem {
  final String key;
  final String? url;
  final String? mimeType;
  final String? kind; // 'image' | 'video' | 'file'
  final String? name;
  final int? size;

  const TaskAttachmentItem({
    required this.key,
    this.url,
    this.mimeType,
    this.kind,
    this.name,
    this.size,
  });

  factory TaskAttachmentItem.fromJson(Map<String, dynamic> json) {
    return TaskAttachmentItem(
      key: json['key'] as String? ?? '',
      url: json['url'] as String?,
      mimeType: json['mime_type'] as String?,
      kind: json['kind'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        if (mimeType != null) 'mime_type': mimeType,
        if (kind != null) 'kind': kind,
        if (name != null) 'name': name,
        if (size != null) 'size': size,
      };
}

/// Task comment — system audit 또는 user comment (+ optional 첨부).
class TaskCommentItem {
  final String id;
  final String taskId;
  final String? userId;
  final String? userName;
  final String content;
  final String kind; // 'comment' | 'system'
  final List<TaskAttachmentItem> attachments;
  final DateTime? createdAt;

  const TaskCommentItem({
    required this.id,
    required this.taskId,
    this.userId,
    this.userName,
    required this.content,
    this.kind = 'comment',
    this.attachments = const [],
    this.createdAt,
  });

  factory TaskCommentItem.fromJson(Map<String, dynamic> json) {
    return TaskCommentItem(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      content: (json['content'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'comment',
      attachments: ((json['attachments'] as List?) ?? [])
          .map((e) => TaskAttachmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Task 담당자 — { user_id, user_name }.
///
/// 신규 task 시스템엔 per-assignee 완료 추적이 없음. isCompleted/completedAt
/// 은 UI 호환 위해 항상 false/null 로 반환 (task-level status 만 의미).
class TaskAssignee {
  final String? userId;
  final String? fullName;

  const TaskAssignee({this.userId, this.fullName});

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      userId: json['user_id'],
      fullName: json['user_name'] ?? json['full_name'],
    );
  }

  /// 호환 alias — 신규 시스템엔 per-assignee 완료 트래킹 없음.
  bool get isCompleted => false;
  DateTime? get completedAt => null;
}
