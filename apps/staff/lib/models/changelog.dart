/// 변경 이력(Changelog / "What's New") 데이터 모델
///
/// 공개(public) 변경 이력 API 응답을 표현.
/// 목록 항목(ChangelogListItem)은 본문(body)이 없고,
/// 상세(ChangelogDetail)는 마크다운 본문을 추가로 포함한다.
/// summary / coverImageUrl 은 nullable.

/// 변경 이력 목록 항목 (본문 없음)
class ChangelogListItem {
  final String slug;
  final String category;
  final String title;
  final String? summary;
  final String? coverImageUrl;
  final List<String> tags;
  final DateTime publishedAt;

  const ChangelogListItem({
    required this.slug,
    required this.category,
    required this.title,
    this.summary,
    this.coverImageUrl,
    this.tags = const [],
    required this.publishedAt,
  });

  /// 서버 JSON → ChangelogListItem 변환 (nullable 필드 방어적 파싱)
  factory ChangelogListItem.fromJson(Map<String, dynamic> json) {
    return ChangelogListItem(
      slug: json['slug'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }
}

/// 변경 이력 상세 (마크다운 본문 포함)
class ChangelogDetail {
  final String slug;
  final String category;
  final String title;
  final String? summary;
  /// 마크다운 본문 (이미지 URL은 이미 절대경로로 resolve 됨)
  final String body;
  final String? coverImageUrl;
  final List<String> tags;
  final DateTime publishedAt;

  const ChangelogDetail({
    required this.slug,
    required this.category,
    required this.title,
    this.summary,
    required this.body,
    this.coverImageUrl,
    this.tags = const [],
    required this.publishedAt,
  });

  /// 서버 JSON → ChangelogDetail 변환 (nullable 필드 방어적 파싱)
  factory ChangelogDetail.fromJson(Map<String, dynamic> json) {
    return ChangelogDetail(
      slug: json['slug'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      body: (json['body'] as String?) ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }
}
