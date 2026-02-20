import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../models/notification.dart';
import 'mock_services.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (AppConstants.useMock) return MockNotificationService();
  return NotificationService(ref.read(dioProvider));
});

class NotificationService {
  final Dio _dio;
  NotificationService(this._dio);

  Future<List<AppNotification>> getNotifications({int? page, int? perPage}) async {
    final response = await _dio.get('/app/my/notifications', queryParameters: {
      if (page != null) 'page': page,
      if (perPage != null) 'per_page': perPage,
    });
    final items = response.data['items'] ?? response.data;
    return (items as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/app/my/notifications/unread-count');
    return response.data['unread_count'] ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/app/my/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.patch('/app/my/notifications/read-all');
  }
}
