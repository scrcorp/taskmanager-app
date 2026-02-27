import 'store.dart';

class AdditionalTask {
  final String id;
  final String? storeId;
  final String? storeName;
  final Store? store;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? createdByName;
  final List<String> assigneeNames;
  final List<TaskAssignee> assignees;
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
