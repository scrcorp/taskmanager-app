import 'store.dart';

class AdditionalTask {
  final String id;
  final Store? store;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? createdByName;
  final List<TaskAssignee> assignees;
  final DateTime? createdAt;

  const AdditionalTask({
    required this.id,
    this.store,
    required this.title,
    this.description,
    this.priority = 'normal',
    this.status = 'pending',
    this.dueDate,
    this.createdByName,
    this.assignees = const [],
    this.createdAt,
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
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      title: json['title'],
      description: json['description'],
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdByName: json['created_by_name'],
      assignees: (json['assignees'] as List<dynamic>?)
              ?.map((e) => TaskAssignee.fromJson(e))
              .toList() ??
          [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
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
