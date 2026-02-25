class AdditionalTask {
  final String id;
  final String title;
  final String? description;
  final String? storeId;
  final String? storeName;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? createdByName;
  final List<String> assigneeNames;
  final DateTime? createdAt;

  const AdditionalTask({
    required this.id,
    required this.title,
    this.description,
    this.storeId,
    this.storeName,
    this.priority = 'normal',
    this.status = 'pending',
    this.dueDate,
    this.createdByName,
    this.assigneeNames = const [],
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
      title: json['title'],
      description: json['description'],
      storeId: json['store_id'],
      storeName: json['store_name'],
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdByName: json['created_by_name'],
      assigneeNames: (json['assignee_names'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
