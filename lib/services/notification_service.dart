import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import 'api_client.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  Future<List<AppNotification>> getNotifications({int? page, int? perPage}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (perPage != null) params['per_page'] = perPage;

    final response = await _dio.get('/app/my/notifications', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/app/my/notifications/unread-count');
    return response.data['count'] ?? response.data['unread_count'] ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/app/my/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.patch('/app/my/notifications/read-all');
  }
}
