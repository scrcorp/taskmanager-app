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
  /// 완료된 항목 수 (미해결 반려 항목 제외)
  int get completedItems =>
      items.where((i) => i.isCompleted && !i.hasUnresolvedRejection).length;
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
/// type: 'completed'(완료), 'rejected'(반려), 'responded'(재응답),
///       'approved'(승인), 'pending'(대기)
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
///
/// 서버 review_status 값: null(리뷰없음), "pass", "fail", "caution", "pending_re_review"
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

  // ── 리뷰 상태 (통합 필드) ──
  /// null(리뷰없음), "pass", "fail", "caution", "pending_re_review"
  final String? reviewStatus;
  final String? reviewComment;
  final List<String> reviewPhotoUrls;
  final String? reviewedBy;
  final String? reviewedAt;

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
    this.reviewStatus,
    this.reviewComment,
    this.reviewPhotoUrls = const [],
    this.reviewedBy,
    this.reviewedAt,
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

  // ── 리뷰 상태 computed getters ──
  /// 반려 상태인지 (fail만 해당, pending_re_review는 재검토 대기)
  bool get isRejected => reviewStatus == 'fail';
  /// 승인 상태인지
  bool get isApproved => reviewStatus == 'pass';
  /// 주의(caution) 상태인지
  bool get isCaution => reviewStatus == 'caution';
  /// 재검토 대기 상태인지 (재응답 후 관리자 재검토 대기)
  bool get isPendingReReview => reviewStatus == 'pending_re_review';

  // ── 호환성 alias (UI에서 사용) ──
  String? get rejectionComment => isRejected ? reviewComment : null;
  List<String> get rejectionPhotoUrls => isRejected ? reviewPhotoUrls : [];
  String? get rejectedBy => isRejected ? reviewedBy : null;
  String? get rejectedAt => isRejected ? reviewedAt : null;
  String? get approvalComment => isApproved ? reviewComment : null;
  List<String> get approvalPhotoUrls => isApproved ? reviewPhotoUrls : [];
  String? get approvedBy => isApproved ? reviewedBy : null;
  String? get approvedAt => isApproved ? reviewedAt : null;

  /// 반려에 대한 재응답이 완료되었는지
  bool get isResolved => respondedAt != null;

  /// 미해결 반려 상태인지 (반려됐지만 아직 재응답 안 함)
  /// pending_re_review는 이미 재응답 완료 상태이므로 해당 없음
  bool get hasUnresolvedRejection => isRejected && !isResolved;

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
    if (isRejected && reviewedAt != null) {
      events.add(ChecklistItemEvent(
        type: 'rejected',
        comment: reviewComment,
        photoUrls: reviewPhotoUrls,
        by: reviewedBy,
        at: reviewedAt,
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
    if (isApproved && reviewedAt != null) {
      events.add(ChecklistItemEvent(
        type: 'approved',
        comment: reviewComment,
        photoUrls: reviewPhotoUrls,
        by: reviewedBy,
        at: reviewedAt,
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

  /// 리뷰 시각 표시 문자열
  String? get reviewedAtDisplay {
    if (reviewedAt == null) return null;
    final parsed = DateTime.tryParse(reviewedAt!);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final hh = parsed.hour.toString().padLeft(2, '0');
      final mi = parsed.minute.toString().padLeft(2, '0');
      return '$mm/$dd $hh:$mi';
    }
    return reviewedAt;
  }

  /// 반려 시각 표시 문자열 (호환성 alias)
  String? get rejectedAtDisplay => isRejected ? reviewedAtDisplay : null;

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
    String? reviewStatus,
    String? reviewComment,
    List<String>? reviewPhotoUrls,
    String? reviewedBy,
    String? reviewedAt,
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
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewComment: reviewComment ?? this.reviewComment,
      reviewPhotoUrls: reviewPhotoUrls ?? this.reviewPhotoUrls,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      responseComment: responseComment ?? this.responseComment,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      history: history ?? this.history,
    );
  }

  /// 서버 JSON → ChecklistItem 변환
  /// [index]: 목록 내 순서 (API 호출 시 itemIndex로 사용)
  factory ChecklistItem.fromJson(Map<String, dynamic> json, int index) {
    // review_status 통합 필드 우선, 구버전 is_rejected/is_approved 폴백
    String? reviewStatus = json['review_status'];
    if (reviewStatus == null) {
      if (json['is_rejected'] == true) {
        reviewStatus = 'fail';
      } else if (json['is_approved'] == true) {
        reviewStatus = 'pass';
      }
    }

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
      reviewStatus: reviewStatus,
      reviewComment: json['review_comment'] ?? json['rejection_comment'] ?? json['approval_comment'],
      reviewPhotoUrls: (json['review_photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['rejection_photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['approval_photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reviewedBy: json['reviewed_by'] ?? json['rejected_by'] ?? json['approved_by'],
      reviewedAt: json['reviewed_at'] ?? json['rejected_at'] ?? json['approved_at'],
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
