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
  int get rejectedItems => items.where((i) => i.isRejected).length;
  bool get hasRejections => rejectedItems > 0;
  List<ChecklistItem> get rejectedItemsList =>
      items.where((i) => i.isRejected).toList();
  int get resolvedItems => items.where((i) => i.isResolved).length;
  List<ChecklistItem> get unresolvedRejections =>
      items.where((i) => i.isRejected && !i.isResolved).toList();

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

class ChecklistItemEvent {
  final String type; // 'completed', 'rejected', 'responded'
  final String? comment;
  final List<String> photoUrls;
  final String? by;
  final String? at;

  const ChecklistItemEvent({
    required this.type,
    this.comment,
    this.photoUrls = const [],
    this.by,
    this.at,
  });

  String? get atDisplay {
    if (at == null) return null;
    final parsed = DateTime.tryParse(at!);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final mi = parsed.minute.toString().padLeft(2, '0');
      return '$mm/$dd $hh:$mi';
    }
    return at;
  }

  factory ChecklistItemEvent.fromJson(Map<String, dynamic> json) {
    return ChecklistItemEvent(
      type: json['type'] ?? 'completed',
      comment: json['comment'],
      photoUrls: (json['photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      by: json['by'],
      at: json['at'],
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
  final String? photoUrl;
  final String? comment;
  final String? completedBy;

  // Rejection/feedback fields
  final bool isRejected;
  final String? rejectionComment;
  final List<String> rejectionPhotoUrls;
  final String? rejectedBy;
  final String? rejectedAt;

  // Response to rejection fields
  final String? responseComment;
  final String? respondedAt;
  final String? respondedBy;

  // Full timeline history
  final List<ChecklistItemEvent> history;

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
    this.photoUrl,
    this.comment,
    this.completedBy,
    this.isRejected = false,
    this.rejectionComment,
    this.rejectionPhotoUrls = const [],
    this.rejectedBy,
    this.rejectedAt,
    this.responseComment,
    this.respondedAt,
    this.respondedBy,
    this.history = const [],
  });

  bool get requiresPhoto => verificationType.contains('photo');
  bool get requiresComment => verificationType.contains('text');
  bool get requiresVerification => verificationType != 'none';

  bool get isResolved => respondedAt != null;

  List<ChecklistItemEvent> get fullHistory {
    if (history.isNotEmpty) return history;
    final events = <ChecklistItemEvent>[];
    if (completedAt != null) {
      events.add(ChecklistItemEvent(
        type: 'completed',
        comment: comment,
        photoUrls: photoUrl != null ? [photoUrl!] : [],
        by: completedBy,
        at: completedAt,
      ));
    }
    if (rejectedAt != null) {
      events.add(ChecklistItemEvent(
        type: 'rejected',
        comment: rejectionComment,
        photoUrls: rejectionPhotoUrls,
        by: rejectedBy,
        at: rejectedAt,
      ));
    }
    if (respondedAt != null) {
      events.add(ChecklistItemEvent(
        type: 'responded',
        comment: responseComment,
        photoUrls: photoUrl != null && isResolved ? [photoUrl!] : [],
        by: respondedBy,
        at: respondedAt,
      ));
    }
    if (events.isEmpty && !isCompleted) {
      events.add(const ChecklistItemEvent(type: 'pending'));
    }
    return events;
  }

  List<String> get allPhotoUrls {
    final urls = <String>[];
    for (final event in fullHistory) {
      urls.addAll(event.photoUrls);
    }
    return urls;
  }

  String? get completedAtDisplay {
    if (completedAt == null) return null;
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

  String? get rejectedAtDisplay {
    if (rejectedAt == null) return null;
    final parsed = DateTime.tryParse(rejectedAt!);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final mi = parsed.minute.toString().padLeft(2, '0');
      return '$mm/$dd $hh:$mi';
    }
    return rejectedAt;
  }

  String? get respondedAtDisplay {
    if (respondedAt == null) return null;
    final parsed = DateTime.tryParse(respondedAt!);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final mi = parsed.minute.toString().padLeft(2, '0');
      return '$mm/$dd $hh:$mi';
    }
    return respondedAt;
  }

  ChecklistItem copyWith({
    bool? isCompleted,
    String? completedAt,
    String? completedTz,
    String? photoUrl,
    String? comment,
    String? completedBy,
    bool? isRejected,
    String? rejectionComment,
    List<String>? rejectionPhotoUrls,
    String? rejectedBy,
    String? rejectedAt,
    String? responseComment,
    String? respondedAt,
    String? respondedBy,
    List<ChecklistItemEvent>? history,
  }) {
    return ChecklistItem(
      index: index,
      templateItemId: templateItemId,
      title: title,
      description: description,
      verificationType: verificationType,
      sortOrder: sortOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedTz: completedTz ?? this.completedTz,
      photoUrl: photoUrl ?? this.photoUrl,
      comment: comment ?? this.comment,
      completedBy: completedBy ?? this.completedBy,
      isRejected: isRejected ?? this.isRejected,
      rejectionComment: rejectionComment ?? this.rejectionComment,
      rejectionPhotoUrls: rejectionPhotoUrls ?? this.rejectionPhotoUrls,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      responseComment: responseComment ?? this.responseComment,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      history: history ?? this.history,
    );
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
      photoUrl: json['photo_url'],
      comment: json['comment'] ?? json['note'],
      completedBy: json['completed_by'] ?? json['completed_by_name'],
      isRejected: json['is_rejected'] ?? false,
      rejectionComment: json['rejection_comment'],
      rejectionPhotoUrls: (json['rejection_photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rejectedBy: json['rejected_by'],
      rejectedAt: json['rejected_at'],
      responseComment: json['response_comment'],
      respondedAt: json['responded_at'],
      respondedBy: json['responded_by'],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => ChecklistItemEvent.fromJson(e))
              .toList() ??
          [],
    );
  }
}
