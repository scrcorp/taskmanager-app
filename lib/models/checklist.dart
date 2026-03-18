/// 체크리스트(Checklist) 데이터 모델
///
/// 근무배정에 연결된 체크리스트 스냅샷과 개별 항목(item)을 표현.
/// 항목별 완료/리뷰/재제출 흐름을 지원한다.
///
/// 구조: ChecklistSnapshot → ChecklistItem
///   - ChecklistItem은 구조화된 files, submissions, reviewsLog, messages를 가짐
///   - 타임라인은 앱에서 이 4가지 목록으로 재구성함

import 'dart:math';

/// 항목 첨부 파일
///
/// context: 'submission'(직원 제출), 'review'(관리자 리뷰), 'chat'(채팅)
class ItemFile {
  final String id;
  final String context;
  final String? contextId;
  final String fileUrl;
  final String fileType;
  final int sortOrder;

  const ItemFile({
    required this.id,
    required this.context,
    this.contextId,
    required this.fileUrl,
    required this.fileType,
    this.sortOrder = 0,
  });

  factory ItemFile.fromJson(Map<String, dynamic> json) {
    return ItemFile(
      id: json['id'] ?? '',
      context: json['context'] ?? 'submission',
      contextId: json['context_id'],
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'photo',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

/// 항목 제출 이력 (직원 제출/재제출)
class ItemSubmission {
  final String id;
  final int version;
  final String? note;
  final String? submittedBy;
  final String? submittedByName;
  final String? submittedAt;

  const ItemSubmission({
    required this.id,
    required this.version,
    this.note,
    this.submittedBy,
    this.submittedByName,
    this.submittedAt,
  });

  factory ItemSubmission.fromJson(Map<String, dynamic> json) {
    return ItemSubmission(
      id: json['id'] ?? '',
      version: json['version'] ?? 1,
      note: json['note'],
      submittedBy: json['submitted_by'],
      submittedByName: json['submitted_by_name'],
      submittedAt: json['submitted_at'],
    );
  }

  /// 제출 시각 표시 문자열 ("MM/DD HH:MM")
  String? get submittedAtDisplay => _formatDateTime(submittedAt);
}

/// 리뷰 이력 (관리자 리뷰 변경 로그)
class ItemReviewLog {
  final String id;
  final String? oldResult;
  final String? newResult;
  final String? comment;
  final String? changedBy;
  final String? changedByName;
  final String? createdAt;

  const ItemReviewLog({
    required this.id,
    this.oldResult,
    this.newResult,
    this.comment,
    this.changedBy,
    this.changedByName,
    this.createdAt,
  });

  factory ItemReviewLog.fromJson(Map<String, dynamic> json) {
    return ItemReviewLog(
      id: json['id'] ?? '',
      oldResult: json['old_result'],
      newResult: json['new_result'],
      comment: json['comment'],
      changedBy: json['changed_by'],
      changedByName: json['changed_by_name'],
      createdAt: json['created_at'],
    );
  }

  /// 리뷰 시각 표시 문자열 ("MM/DD HH:MM")
  String? get createdAtDisplay => _formatDateTime(createdAt);
}

/// 채팅 메시지
class ItemMessage {
  final String id;
  final String? authorId;
  final String? authorName;
  final String content;
  final String? createdAt;

  const ItemMessage({
    required this.id,
    this.authorId,
    this.authorName,
    required this.content,
    this.createdAt,
  });

  factory ItemMessage.fromJson(Map<String, dynamic> json) {
    return ItemMessage(
      id: json['id'] ?? '',
      authorId: json['author_id'],
      authorName: json['author_name'],
      content: json['content'] ?? '',
      createdAt: json['created_at'],
    );
  }

  /// 메시지 시각 표시 문자열 ("MM/DD HH:MM")
  String? get createdAtDisplay => _formatDateTime(createdAt);
}

/// 타임라인 이벤트 (앱에서 구조화된 데이터로 재구성)
///
/// type: 'submitted', 'resubmitted', 'rejected', 'approved', 'message',
///       'message_photo', 'review_photo', 'pending'
class ChecklistItemEvent {
  final String type;
  final String? comment;
  final List<String> photoUrls;
  final String? by;
  final String? byName;
  final String? at;

  const ChecklistItemEvent({
    required this.type,
    this.comment,
    this.photoUrls = const [],
    this.by,
    this.byName,
    this.at,
  });

  /// 이벤트 시각 표시 문자열 ("MM/DD HH:MM")
  String? get atDisplay => _formatDateTime(at);
}

/// 날짜/시간 문자열 → "MM/DD HH:MM" 형식 변환 (공통 헬퍼)
String? _formatDateTime(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mi = parsed.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$mi';
  }
  return value;
}

/// 체크리스트 스냅샷 (근무배정에 포함되는 체크리스트 전체)
class ChecklistSnapshot {
  final String? templateId;
  final String? templateName;
  final String? snapshotAt;
  final String? reportedAt;
  final List<ChecklistItem> items;

  const ChecklistSnapshot({
    this.templateId,
    this.templateName,
    this.snapshotAt,
    this.reportedAt,
    required this.items,
  });

  /// 보고서 제출 여부
  bool get isReported => reportedAt != null;

  /// 전체 항목 수
  int get totalItems => items.length;

  /// 완료된 항목 수 (미해결 반려 항목 제외)
  int get completedItems =>
      items.where((i) => i.isCompleted && !i.hasUnresolvedRejection).length;

  /// 완료 비율 (0.0 ~ 1.0)
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;

  /// 전체 완료 여부
  bool get isAllCompleted => totalItems > 0 && completedItems == totalItems;

  /// 모든 항목 리뷰 통과 여부
  bool get isAllPassed =>
      totalItems > 0 && items.every((i) => i.isApproved);

  /// 반려된 항목 수
  int get rejectedItems => items.where((i) => i.isRejected).length;

  /// 반려 항목 존재 여부
  bool get hasRejections => rejectedItems > 0;

  /// 반려된 항목 목록
  List<ChecklistItem> get rejectedItemsList =>
      items.where((i) => i.isRejected).toList();

  /// 아직 해결되지 않은 반려 항목 목록
  List<ChecklistItem> get unresolvedRejections =>
      items.where((i) => i.isRejected && !i.isResolved).toList();

  /// 서버 JSON (Map 형태) → ChecklistSnapshot 변환
  factory ChecklistSnapshot.fromJson(Map<String, dynamic> json) {
    // items 키가 있으면 사용, 없으면 빈 목록
    final rawItems = json['items'] as List<dynamic>?;
    return ChecklistSnapshot(
      templateId: json['template_id'],
      templateName: json['template_name'],
      snapshotAt: json['snapshot_at'],
      reportedAt: json['reported_at'],
      items: rawItems
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

/// 체크리스트 개별 항목
///
/// 서버 review_result 값: null(리뷰없음), "pass", "fail", "pending_re_review"
class ChecklistItem {
  /// 목록 내 순서 인덱스 (API 호출 시 사용)
  final int index;
  final String id;
  final int itemIndex;
  final String title;
  final String? description;

  /// 인증 유형: 'none', 'photo', 'text', 'photo_text' 등
  final String verificationType;
  final int? minPhotos;
  final int? maxPhotos;
  final int sortOrder;
  final bool isCompleted;
  final String? completedAt;
  final String? completedTz;
  final String? completedBy;
  final String? completedByName;

  // ── 새 구조화된 리뷰/제출 필드 ──
  final String? reviewResult; // null, "pass", "fail", "pending_re_review"
  final String? reviewerId;
  final String? reviewerName;
  final String? reviewedAt;
  final List<ItemFile> files;
  final List<ItemSubmission> submissions;
  final List<ItemReviewLog> reviewsLog;
  final List<ItemMessage> messages;

  const ChecklistItem({
    required this.index,
    required this.id,
    this.itemIndex = 0,
    required this.title,
    this.description,
    this.verificationType = 'none',
    this.minPhotos,
    this.maxPhotos,
    this.sortOrder = 0,
    this.isCompleted = false,
    this.completedAt,
    this.completedTz,
    this.completedBy,
    this.completedByName,
    this.reviewResult,
    this.reviewerId,
    this.reviewerName,
    this.reviewedAt,
    this.files = const [],
    this.submissions = const [],
    this.reviewsLog = const [],
    this.messages = const [],
  });

  // ── 인증 유형 computed getters ──
  bool get requiresPhoto => verificationType.contains('photo');
  bool get requiresComment => verificationType.contains('text');
  bool get requiresVerification => verificationType != 'none';

  // ── 리뷰 상태 computed getters ──
  bool get isRejected => reviewResult == 'fail';
  bool get isApproved => reviewResult == 'pass';
  bool get isPendingReReview => reviewResult == 'pending_re_review';

  // ── 파일/제출 computed getters ──
  /// 최신 제출 사진 URL 목록 (최신 submission의 context_id로 필터)
  List<String> get photoUrls {
    final latestSub = submissions.isNotEmpty ? submissions.last : null;
    if (latestSub != null) {
      final filtered = files
          .where((f) => f.context == 'submission' && f.contextId == latestSub.id)
          .map((f) => f.fileUrl)
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    // fallback: 전체 submission 파일
    return files
        .where((f) => f.context == 'submission')
        .map((f) => f.fileUrl)
        .toList();
  }

  /// 리뷰 사진 URL 목록 (context='review')
  List<String> get reviewPhotoUrls => files
      .where((f) => f.context == 'review')
      .map((f) => f.fileUrl)
      .toList();

  /// 채팅 사진 URL 목록 (context='chat')
  List<String> get chatPhotoUrls => files
      .where((f) => f.context == 'chat')
      .map((f) => f.fileUrl)
      .toList();

  bool get hasPhotos => photoUrls.isNotEmpty;

  /// 첫 번째 제출 사진 (단일 사진 호환용)
  String? get photoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;

  /// 최신 제출의 노트
  String? get note =>
      submissions.isNotEmpty ? submissions.last.note : null;

  /// 최신 리뷰 로그의 코멘트
  String? get reviewComment =>
      reviewsLog.isNotEmpty ? reviewsLog.last.comment : null;

  // ── 호환성 alias (work_screen.dart 등에서 사용) ──
  String? get approvalComment => isApproved ? reviewComment : null;
  List<String> get approvalPhotoUrls => isApproved ? reviewPhotoUrls : [];
  String? get approvedBy => isApproved ? reviewerName : null;
  String? get approvedAt => isApproved ? reviewedAt : null;
  String? get rejectionComment => isRejected ? reviewComment : null;
  List<String> get rejectionPhotoUrls => isRejected ? reviewPhotoUrls : [];
  String? get rejectedBy => isRejected ? reviewerName : null;
  String? get rejectedAt => isRejected ? reviewedAt : null;
  String? get rejectedAtDisplay => isRejected ? reviewedAtDisplay : null;
  String? get reviewedAtDisplay => _formatDateTime(reviewedAt);

  /// 재제출 횟수 (초기 제출 제외)
  int get resubmissionCount => max(submissions.length - 1, 0);

  /// 반려 이후 재제출이 완료된 상태인지
  ///
  /// review_result가 'fail'인 상태에서 마지막 fail 리뷰 로그 이후에
  /// 추가 submission이 있으면 해결된 것으로 본다.
  /// (서버가 pending_re_review로 바꾸기 전의 중간 상태를 커버)
  bool get isResolved {
    if (!isRejected) return false;
    if (submissions.isEmpty) return false;
    // 마지막 fail 리뷰 로그의 생성 시각을 찾음
    String? lastFailAt;
    for (var i = reviewsLog.length - 1; i >= 0; i--) {
      if (reviewsLog[i].newResult == 'fail') {
        lastFailAt = reviewsLog[i].createdAt;
        break;
      }
    }
    if (lastFailAt == null) return false;
    // fail 이후에 생성된 submission이 있으면 해결된 것
    return submissions.any((s) =>
        s.submittedAt != null && s.submittedAt!.compareTo(lastFailAt!) > 0);
  }

  /// 미해결 반려 상태인지 (반려됐지만 아직 재응답 안 함)
  bool get hasUnresolvedRejection => isRejected && !isResolved;

  /// 완료 시각 표시 문자열 ("MM/DD HH:MM [TZ]")
  String? get completedAtDisplay {
    if (completedAt == null) return null;
    final base = _formatDateTime(completedAt);
    return completedTz != null ? '$base $completedTz' : base;
  }

  /// 타임라인 이벤트 목록 (submissions + reviewsLog + messages + files 통합)
  List<ChecklistItemEvent> get fullHistory {
    final events = <_TimedEvent>[];

    // 제출 이력
    for (var i = 0; i < submissions.length; i++) {
      final sub = submissions[i];
      final subPhotos = files
          .where((f) => f.context == 'submission' && f.contextId == sub.id)
          .map((f) => f.fileUrl)
          .toList();
      // contextId 매칭이 없으면 첫 번째 제출에 모든 submission 파일 할당
      final photos = subPhotos.isNotEmpty
          ? subPhotos
          : (i == 0
              ? files
                  .where((f) => f.context == 'submission')
                  .map((f) => f.fileUrl)
                  .toList()
              : <String>[]);
      events.add(_TimedEvent(
        at: sub.submittedAt,
        event: ChecklistItemEvent(
          type: i == 0 ? 'submitted' : 'resubmitted',
          comment: sub.note,
          photoUrls: photos,
          by: sub.submittedBy,
          byName: sub.submittedByName,
          at: sub.submittedAt,
        ),
      ));
    }

    // submissions가 없지만 완료된 항목 → fallback submitted 이벤트
    if (submissions.isEmpty && isCompleted) {
      final fallbackPhotos = files
          .where((f) => f.context == 'submission')
          .map((f) => f.fileUrl)
          .toList();
      events.add(_TimedEvent(
        at: completedAt,
        event: ChecklistItemEvent(
          type: 'submitted',
          comment: note,
          photoUrls: fallbackPhotos,
          by: completedBy,
          at: completedAt,
        ),
      ));
    }

    // 리뷰 이력
    for (final log in reviewsLog) {
      final logPhotos = files
          .where((f) => f.context == 'review' && f.contextId == log.id)
          .map((f) => f.fileUrl)
          .toList();
      final photos =
          logPhotos.isNotEmpty ? logPhotos : reviewPhotoUrls;
      final type = log.newResult == 'pass'
          ? 'approved'
          : log.newResult == 'fail'
              ? 'rejected'
              : 'pending_re_review';
      events.add(_TimedEvent(
        at: log.createdAt,
        event: ChecklistItemEvent(
          type: type,
          comment: log.comment,
          photoUrls: photos,
          by: log.changedBy,
          byName: log.changedByName,
          at: log.createdAt,
        ),
      ));
    }

    // 채팅 메시지
    for (final msg in messages) {
      events.add(_TimedEvent(
        at: msg.createdAt,
        event: ChecklistItemEvent(
          type: 'message',
          comment: msg.content,
          by: msg.authorId,
          byName: msg.authorName,
          at: msg.createdAt,
        ),
      ));
    }

    // 채팅 사진 — messages 목록에서 photo 콘텐츠와 매칭하여 작성자/시간 포함
    for (final f in files.where((f) => f.context == 'chat')) {
      // 해당 파일과 동일 contextId를 가진 메시지에서 작성자 정보 찾기
      final relatedMsg = messages.cast<ItemMessage?>().firstWhere(
        (m) => m != null && f.contextId != null && m.id == f.contextId,
        orElse: () => null,
      );
      events.add(_TimedEvent(
        at: relatedMsg?.createdAt,
        event: ChecklistItemEvent(
          type: 'message_photo',
          photoUrls: [f.fileUrl],
          by: relatedMsg?.authorId,
          byName: relatedMsg?.authorName,
          at: relatedMsg?.createdAt,
        ),
      ));
    }

    // 시간순 정렬
    events.sort((a, b) {
      if (a.at == null && b.at == null) return 0;
      if (a.at == null) return 1;
      if (b.at == null) return -1;
      return a.at!.compareTo(b.at!);
    });

    if (events.isEmpty && !isCompleted) {
      return [const ChecklistItemEvent(type: 'pending')];
    }

    return events.map((e) => e.event).toList();
  }

  /// 일부 필드만 변경한 새 인스턴스 생성
  ChecklistItem copyWith({
    bool? isCompleted,
    String? completedAt,
    String? completedTz,
    String? completedBy,
    String? completedByName,
    String? reviewResult,
    String? reviewerId,
    String? reviewerName,
    String? reviewedAt,
    List<ItemFile>? files,
    List<ItemSubmission>? submissions,
    List<ItemReviewLog>? reviewsLog,
    List<ItemMessage>? messages,
  }) {
    return ChecklistItem(
      index: index,
      id: id,
      itemIndex: itemIndex,
      title: title,
      description: description,
      verificationType: verificationType,
      minPhotos: minPhotos,
      maxPhotos: maxPhotos,
      sortOrder: sortOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedTz: completedTz ?? this.completedTz,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      reviewResult: reviewResult ?? this.reviewResult,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      files: files ?? this.files,
      submissions: submissions ?? this.submissions,
      reviewsLog: reviewsLog ?? this.reviewsLog,
      messages: messages ?? this.messages,
    );
  }

  /// 서버 JSON → ChecklistItem 변환
  /// [index]: 목록 내 순서 (API 호출 시 itemIndex로 사용)
  factory ChecklistItem.fromJson(Map<String, dynamic> json, int index) {
    return ChecklistItem(
      index: index,
      id: json['id'] ?? '',
      itemIndex: json['item_index'] ?? index,
      title: json['title'] ?? '',
      description: json['description'],
      verificationType: json['verification_type'] ?? 'none',
      minPhotos: json['min_photos'],
      maxPhotos: json['max_photos'],
      sortOrder: json['sort_order'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'],
      completedTz: json['completed_tz'],
      completedBy: json['completed_by'],
      completedByName: json['completed_by_name'],
      reviewResult: json['review_result'],
      reviewerId: json['reviewer_id'],
      reviewerName: json['reviewer_name'],
      reviewedAt: json['reviewed_at'],
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => ItemFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      submissions: (json['submissions'] as List<dynamic>?)
              ?.map((e) => ItemSubmission.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reviewsLog: (json['reviews_log'] as List<dynamic>?)
              ?.map((e) => ItemReviewLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => ItemMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 타임라인 정렬용 내부 헬퍼
class _TimedEvent {
  final String? at;
  final ChecklistItemEvent event;
  const _TimedEvent({required this.at, required this.event});
}
