class Voice {
  final String id;
  final String title;
  final String? content;
  final String category;
  final String status;
  final String priority;
  final String? storeId;
  final String createdBy;
  final String? createdByName;
  final String? resolvedBy;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Voice({
    required this.id,
    required this.title,
    this.content,
    required this.category,
    required this.status,
    required this.priority,
    this.storeId,
    required this.createdBy,
    this.createdByName,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      category: json['category'] ?? 'other',
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'normal',
      storeId: json['store_id'],
      createdBy: json['created_by'],
      createdByName: json['created_by_name'],
      resolvedBy: json['resolved_by'],
      resolvedByName: json['resolved_by_name'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
