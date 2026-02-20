import 'store.dart';

class Announcement {
  final String id;
  final Store? store;
  final String title;
  final String content;
  final String? createdByName;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    this.store,
    required this.title,
    required this.content,
    this.createdByName,
    this.createdAt,
  });

  String get scope => store?.name ?? 'All';

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
      title: json['title'],
      content: json['content'] ?? '',
      createdByName: json['created_by_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
