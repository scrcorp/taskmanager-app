/// 공지사항(Announcement) 데이터 모델
///
/// 관리자가 작성한 공지사항과 관련 댓글/확인(acknowledge) 정보를 포함.
/// store가 null이면 전체 공지, store가 있으면 해당 매장 한정 공지.
import 'store.dart';

/// 공지사항 본체
class Announcement {
  final String id;
  /// 공지 대상 매장 (null이면 전체 조직 대상)
  final Store? store;
  final String title;
  final String content;
  final String? createdByName;
  final DateTime? createdAt;
  /// 공지에 달린 댓글 목록
  final List<NoticeComment> comments;
  /// 공지를 확인한 직원 목록
  final List<NoticeAcknowledgment> acknowledgments;
  /// 현재 사용자의 확인 여부
  final bool isAcknowledged;

  const Announcement({
    required this.id,
    this.store,
    required this.title,
    required this.content,
    this.createdByName,
    this.createdAt,
    this.comments = const [],
    this.acknowledgments = const [],
    this.isAcknowledged = false,
  });

  /// 공지 범위 표시 문자열 (매장명 또는 'All')
  String get scope => store?.name ?? 'All';

  /// 댓글/확인 상태만 변경한 새 인스턴스 생성
  Announcement copyWith({
    List<NoticeComment>? comments,
    List<NoticeAcknowledgment>? acknowledgments,
    bool? isAcknowledged,
  }) {
    return Announcement(
      id: id,
      store: store,
      title: title,
      content: content,
      createdByName: createdByName,
      createdAt: createdAt,
      comments: comments ?? this.comments,
      acknowledgments: acknowledgments ?? this.acknowledgments,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }

  /// 서버 JSON → Announcement 객체 변환
  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      title: json['title'],
      content: json['content'] ?? '',
      createdByName: json['created_by_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => NoticeComment.fromJson(e))
              .toList() ??
          [],
      acknowledgments: (json['acknowledgments'] as List<dynamic>?)
              ?.map((e) => NoticeAcknowledgment.fromJson(e))
              .toList() ??
          [],
      isAcknowledged: json['is_acknowledged'] ?? false,
    );
  }
}

/// 공지사항 댓글
class NoticeComment {
  final String id;
  final String userId;
  final String? userName;
  final String text;
  final DateTime createdAt;
  /// 좋아요 수
  final int likes;
  /// 현재 사용자의 좋아요 여부
  final bool isLiked;

  const NoticeComment({
    required this.id,
    required this.userId,
    this.userName,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
  });

  /// 서버 JSON → NoticeComment 객체 변환
  factory NoticeComment.fromJson(Map<String, dynamic> json) {
    return NoticeComment(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']),
      likes: json['likes'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }
}

/// 공지 확인(Acknowledgment) 기록
///
/// 직원이 공지를 읽었음을 확인한 시점과 정보를 기록한다.
class NoticeAcknowledgment {
  final String userId;
  final String? userName;
  final DateTime acknowledgedAt;

  const NoticeAcknowledgment({
    required this.userId,
    this.userName,
    required this.acknowledgedAt,
  });

  /// 서버 JSON → NoticeAcknowledgment 객체 변환
  factory NoticeAcknowledgment.fromJson(Map<String, dynamic> json) {
    return NoticeAcknowledgment(
      userId: json['user_id'],
      userName: json['user_name'],
      acknowledgedAt: DateTime.parse(json['acknowledged_at']),
    );
  }
}
