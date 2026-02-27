import 'store.dart';

class Announcement {
  final String id;
  final Store? store;
  final String title;
  final String content;
  final String? createdByName;
  final DateTime? createdAt;
  final List<NoticeComment> comments;
  final List<NoticeAcknowledgment> acknowledgments;
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

  String get scope => store?.name ?? 'All';

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

class NoticeComment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;

  const NoticeComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
  });

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

class NoticeAcknowledgment {
  final String userId;
  final String userName;
  final DateTime acknowledgedAt;

  const NoticeAcknowledgment({
    required this.userId,
    required this.userName,
    required this.acknowledgedAt,
  });

  factory NoticeAcknowledgment.fromJson(Map<String, dynamic> json) {
    return NoticeAcknowledgment(
      userId: json['user_id'],
      userName: json['user_name'],
      acknowledgedAt: DateTime.parse(json['acknowledged_at']),
    );
  }
}
