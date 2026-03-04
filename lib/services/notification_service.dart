/// 알림(Notification) API 서비스
///
/// 알림 목록 조회, 미읽음 수 조회, 개별/일괄 읽음 처리 API를 호출.
/// 엔드포인트: /app/my/notifications/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import 'api_client.dart';

/// 알림 서비스 Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

/// 알림 API 서비스 클래스
class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  /// 알림 목록 조회 — 페이지네이션 지원
  ///
  /// 응답 형식이 배열 또는 { items/data: [...] } 모두 대응.
  Future<List<AppNotification>> getNotifications({int? page, int? perPage}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (perPage != null) params['per_page'] = perPage;

    final response = await _dio.get('/app/my/notifications', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// 미읽음 알림 수 조회 — 헤더 배지 표시용 (가벼운 API)
  ///
  /// 응답에서 count 또는 unread_count 키를 확인 (서버 버전 호환).
  Future<int> getUnreadCount() async {
    final response = await _dio.get('/app/my/notifications/unread-count');
    return response.data['count'] ?? response.data['unread_count'] ?? 0;
  }

  /// 개별 알림 읽음 처리
  Future<void> markAsRead(String id) async {
    await _dio.patch('/app/my/notifications/$id/read');
  }

  /// 모든 알림 일괄 읽음 처리
  Future<void> markAllAsRead() async {
    await _dio.patch('/app/my/notifications/read-all');
  }
}
