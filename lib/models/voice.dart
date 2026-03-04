/// 직원 의견(Voice) 데이터 모델
///
/// 직원이 홈 화면에서 아이디어/건의/시설/안전 등의 의견을 제출하는 기능.
/// 카테고리별 분류와 우선순위를 지원하며, 관리자가 해결 처리할 수 있다.
class Voice {
  final String id;
  final String title;
  final String? content;
  /// 카테고리: 'idea', 'facility', 'safety', 'hr', 'other'
  final String category;
  /// 상태: 'open', 'resolved' 등
  final String status;
  /// 우선순위: 'low', 'normal', 'high', 'urgent'
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

  /// 서버 JSON → Voice 객체 변환
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
