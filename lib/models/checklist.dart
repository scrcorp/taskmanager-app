class ChecklistSnapshot {
  final String? templateId;
  final String? templateName;
  final String? snapshotAt;
  final List<ChecklistItem> items;

  const ChecklistSnapshot({
    this.templateId,
    this.templateName,
    this.snapshotAt,
    required this.items,
  });

  int get totalItems => items.length;
  int get completedItems => items.where((i) => i.isCompleted).length;
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;
  bool get isAllCompleted => totalItems > 0 && completedItems == totalItems;

  factory ChecklistSnapshot.fromJson(Map<String, dynamic> json) {
    return ChecklistSnapshot(
      templateId: json['template_id'],
      templateName: json['template_name'],
      snapshotAt: json['snapshot_at'],
      items: (json['items'] as List<dynamic>?)
              ?.asMap()
              .entries
              .map((e) => ChecklistItem.fromJson(e.value, e.key))
              .toList() ??
          [],
    );
  }

  /// Server may return checklist_snapshot as a plain items array
  factory ChecklistSnapshot.fromItemsList(List<dynamic> items) {
    return ChecklistSnapshot(
      items: items
          .asMap()
          .entries
          .map((e) => ChecklistItem.fromJson(e.value, e.key))
          .toList(),
    );
  }
}

class ChecklistItem {
  final int index;
  final String? templateItemId;
  final String title;
  final String? description;
  final String verificationType;
  final int sortOrder;
  final bool isCompleted;
  final String? completedAt;
  final String? completedTz;

  const ChecklistItem({
    required this.index,
    this.templateItemId,
    required this.title,
    this.description,
    this.verificationType = 'none',
    this.sortOrder = 0,
    this.isCompleted = false,
    this.completedAt,
    this.completedTz,
  });

  /// Formatted completion time string (e.g. "02/20 14:05 PST")
  String? get completedAtDisplay {
    if (completedAt == null) return null;
    // Parse "2026-02-20T14:05" format
    final parsed = DateTime.tryParse(completedAt!);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final mi = parsed.minute.toString().padLeft(2, '0');
      final dateTime = '$mm/$dd $hh:$mi';
      return completedTz != null ? '$dateTime $completedTz' : dateTime;
    }
    return completedTz != null ? '$completedAt $completedTz' : completedAt;
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json, int index) {
    return ChecklistItem(
      index: index,
      templateItemId: json['template_item_id'],
      title: json['title'],
      description: json['description'],
      verificationType: json['verification_type'] ?? 'none',
      sortOrder: json['sort_order'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'],
      completedTz: json['completed_tz'],
    );
  }
}
