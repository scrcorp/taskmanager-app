/// 추가 업무(Additional Task) 데이터 모델
///
/// 체크리스트와 별도로 관리자가 직원에게 배정하는 개별 업무.
/// DB 테이블명: additional_tasks (코드에서 'tasks'로 약칭)
/// 우선순위(urgent/high/normal/low)와 상태(pending/in_progress/completed)를 지원.
import 'store.dart';

/// 추가 업무 본체
class AdditionalTask {
  final String id;
  final String? storeId;
  final String? storeName;
  final Store? store;
  final String title;
  final String? description;
  /// 우선순위: 'urgent', 'high', 'normal', 'low'
  final String priority;
  /// 상태: 'pending', 'in_progress', 'completed'
  final String status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? createdByName;
  /// 담당자 이름 목록 (간략 버전)
  final List<String> assigneeNames;
  /// 담당자 상세 정보 목록 (완료 여부 포함)
  final List<TaskAssignee> assignees;
  /// 라벨 태그 목록
  final List<String> labels;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? completedByName;

  const AdditionalTask({
    required this.id,
    this.storeId,
    this.storeName,
    this.store,
    required this.title,
    this.description,
    this.priority = 'normal',
    this.status = 'pending',
    this.startDate,
    this.dueDate,
    this.createdByName,
    this.assigneeNames = const [],
    this.assignees = const [],
    this.labels = const [],
    this.createdAt,
    this.completedAt,
    this.completedByName,
  });

  /// 우선순위를 사용자에게 표시할 라벨로 변환
  String get priorityLabel {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  /// 상태를 사용자에게 표시할 라벨로 변환
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  /// 서버 JSON → AdditionalTask 객체 변환
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
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdByName: json['created_by_name'],
      assigneeNames: (json['assignee_names'] as List<dynamic>?)?.cast<String>() ?? [],
      assignees: (json['assignees'] as List<dynamic>?)
              ?.map((e) => TaskAssignee.fromJson(e))
              .toList() ??
          [],
      labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      completedByName: json['completed_by_name'],
    );
  }
}

/// 업무 담당자 정보
///
/// 개별 담당자의 완료 여부를 추적하여
/// 다중 담당자 업무의 진행 상태를 파악할 수 있다.
class TaskAssignee {
  final String userId;
  final String? fullName;
  final bool isCompleted;
  final DateTime? completedAt;

  const TaskAssignee({
    required this.userId,
    this.fullName,
    this.isCompleted = false,
    this.completedAt,
  });

  /// 서버 JSON → TaskAssignee 객체 변환
  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      userId: json['user_id'],
      fullName: json['full_name'],
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
}
