/// 체크리스트(Checklist) 데이터 모델
///
/// 근무배정에 연결된 체크리스트 스냅샷과 개별 항목(item)을 표현.
/// 항목별 완료/반려/재응답 흐름과 이벤트 타임라인을 지원한다.
///
/// 구조: ChecklistSnapshot → ChecklistItem → ChecklistItemEvent
/// - 스냅샷: 템플릿에서 복사된 체크리스트 전체
/// - 항목: 개별 체크 항목 (사진/코멘트 인증 가능)
/// - 이벤트: 완료/반려/재응답 등 시간순 기록

/// 체크리스트 스냅샷 (근무배정에 포함되는 체크리스트 전체)
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

  /// 전체 항목 수
  int get totalItems => items.length;
  /// 완료된 항목 수
  int get completedItems => items.where((i) => i.isCompleted).length;
  /// 완료 비율 (0.0 ~ 1.0)
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;
  /// 전체 완료 여부
  bool get isAllCompleted => totalItems > 0 && completedItems == totalItems;
  /// 반려된 항목 수
  int get rejectedItems => items.where((i) => i.isRejected).length;
  /// 반려 항목 존재 여부
  bool get hasRejections => rejectedItems > 0;
  /// 반려된 항목 목록
  List<ChecklistItem> get rejectedItemsList =>
      items.where((i) => i.isRejected).toList();
  /// 재응답(해결)된 항목 수
  int get resolvedItems => items.where((i) => i.isResolved).length;
  /// 아직 해결되지 않은 반려 항목 목록
  List<ChecklistItem> get unresolvedRejections =>
      items.where((i) => i.isRejected && !i.isResolved).toList();

  /// 서버 JSON (Map 형태) → ChecklistSnapshot 변환
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

  /// 서버 JSON (List 형태, 구버전 호환) → ChecklistSnapshot 변환
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

/// 체크리스트 항목의 개별 이벤트 (타임라인 기록)
///
/// type: 'completed'(완료), 'rejected'(반려), 'responded'(재응답), 'pending'(대기)
class ChecklistItemEvent {
  final String type;
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

  /// 이벤트 시각을 "MM/DD HH:MM" 형식으로 표시
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

  /// 서버 JSON → ChecklistItemEvent 변환
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

/// 체크리스트 개별 항목
///
/// 인증 유형(verificationType)에 따라 사진/코멘트 입력이 필요할 수 있다.
/// 관리자가 반려(reject)하면 직원이 재응답(respond)하는 흐름을 지원.
class ChecklistItem {
  /// 목록 내 순서 인덱스 (API 호출 시 사용)
  final int index;
  final String? templateItemId;
  final String title;
  final String? description;
  /// 인증 유형: 'none', 'photo', 'text', 'photo_text' 등
  final String verificationType;
  final int sortOrder;
  final bool isCompleted;
  final String? completedAt;
  /// 완료 시 타임존 정보
  final String? completedTz;
  final String? photoUrl;
  final String? comment;
  final String? completedBy;

  // ── 반려(Rejection) 관련 필드 ──
  final bool isRejected;
  final String? rejectionComment;
  final List<String> rejectionPhotoUrls;
  final String? rejectedBy;
  final String? rejectedAt;

  // ── 반려에 대한 재응답(Response) 관련 필드 ──
  final String? responseComment;
  final String? respondedAt;
  final String? respondedBy;

  // ── 전체 타임라인 이력 ──
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

  /// 사진 인증이 필요한 항목인지
  bool get requiresPhoto => verificationType.contains('photo');
  /// 코멘트 인증이 필요한 항목인지
  bool get requiresComment => verificationType.contains('text');
  /// 어떤 형태든 인증이 필요한 항목인지
  bool get requiresVerification => verificationType != 'none';

  /// 반려에 대한 재응답이 완료되었는지
  bool get isResolved => respondedAt != null;

  /// 전체 이벤트 타임라인 (서버에서 history를 제공하지 않을 경우 개별 필드로 재구성)
  List<ChecklistItemEvent> get fullHistory {
    if (history.isNotEmpty) return history;
    // 서버가 history 필드를 주지 않는 경우, 개별 필드로 이벤트 재구성
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

  /// 모든 이벤트의 사진 URL을 시간순으로 통합
  List<String> get allPhotoUrls {
    final urls = <String>[];
    for (final event in fullHistory) {
      urls.addAll(event.photoUrls);
    }
    return urls;
  }

  /// 완료 시각 표시 문자열 ("MM/DD HH:MM [TZ]")
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

  /// 반려 시각 표시 문자열
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

  /// 재응답 시각 표시 문자열
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

  /// 일부 필드만 변경한 새 인스턴스 생성
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

  /// 서버 JSON → ChecklistItem 변환
  /// [index]: 목록 내 순서 (API 호출 시 itemIndex로 사용)
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
