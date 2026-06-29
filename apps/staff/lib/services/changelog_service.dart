/// 변경 이력(Changelog / "What's New") API 서비스
///
/// 공개(public)·비인증 엔드포인트를 호출한다. 스태프 앱은 항상
/// category=staff_app 으로 필터링한다.
/// 엔드포인트(트레일링 슬래시 필수):
///   - GET /public/changelog/            (목록)
///   - GET /public/changelog/{slug}/     (상세)
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/changelog.dart';
import 'api_client.dart';

/// 변경 이력 서비스 Provider
final changelogServiceProvider = Provider<ChangelogService>((ref) {
  return ChangelogService(ref.read(dioProvider));
});

/// 목록 조회 결과 (페이지네이션 메타 포함)
class ChangelogListResult {
  final List<ChangelogListItem> items;
  final int total;
  final int page;
  final int perPage;
  final int pages;

  const ChangelogListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    required this.pages,
  });
}

/// 변경 이력 API 서비스 클래스
class ChangelogService {
  final Dio _dio;

  /// 스태프 앱 고정 카테고리
  static const String _category = 'staff_app';

  ChangelogService(this._dio);

  /// 변경 이력 목록 조회 — 항상 category=staff_app 필터.
  ///
  /// 트레일링 슬래시 필수: '/public/changelog/'
  Future<ChangelogListResult> getList({String? q, int page = 1}) async {
    final params = <String, dynamic>{
      'category': _category,
      'page': page,
    };
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();

    final response = await _dio.get('/public/changelog/', queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final list = (data['items'] as List<dynamic>? ?? const [])
        .map((e) => ChangelogListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChangelogListResult(
      items: list,
      total: (data['total'] as num?)?.toInt() ?? list.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      perPage: (data['per_page'] as num?)?.toInt() ?? list.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  /// 변경 이력 상세 조회 — 트레일링 슬래시 필수: '/public/changelog/{slug}/'
  Future<ChangelogDetail> getDetail(String slug) async {
    final response = await _dio.get('/public/changelog/$slug/');
    return ChangelogDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
