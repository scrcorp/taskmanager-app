/// 공지사항(Announcement) API 서비스
///
/// 공지 목록 조회, 상세 조회, 댓글 추가, 확인(acknowledge) 토글 API를 호출.
/// 엔드포인트: /app/my/announcements/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import 'api_client.dart';

/// 공지사항 서비스 Provider
final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService(ref.read(dioProvider));
});

/// 공지사항 API 서비스 클래스
class AnnouncementService {
  final Dio _dio;

  AnnouncementService(this._dio);

  /// 공지 목록 조회 — 페이지네이션 지원
  ///
  /// 응답이 배열이면 그대로, 객체이면 items 또는 data 키에서 목록 추출.
  /// 서버 응답 형식 변경에 유연하게 대응하기 위한 방어적 파싱.
  Future<List<Announcement>> getAnnouncements({int? page, int? perPage}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (perPage != null) params['per_page'] = perPage;

    final response = await _dio.get('/app/my/announcements', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Announcement.fromJson(e)).toList();
  }

  /// 공지 상세 조회 — 댓글, 확인 목록 포함
  Future<Announcement> getAnnouncement(String id) async {
    final response = await _dio.get('/app/my/announcements/$id');
    return Announcement.fromJson(response.data);
  }

  /// 공지에 댓글 추가 — 새 댓글 객체 반환
  Future<NoticeComment> addComment(String announcementId, String text) async {
    final response = await _dio.post(
      '/app/my/announcements/$announcementId/comments',
      data: {'text': text},
    );
    return NoticeComment.fromJson(response.data);
  }

  /// 공지 확인(읽음) 상태 토글 — PATCH로 acknowledge 상태 변경
  Future<void> toggleAcknowledge(String announcementId) async {
    await _dio.patch('/app/my/announcements/$announcementId/acknowledge');
  }
}
