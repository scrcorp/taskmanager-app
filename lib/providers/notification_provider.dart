/// 알림(Notification) 상태 관리 Provider
///
/// 앱 내 알림 목록 조회, 읽음 처리, 미읽음 카운트를 관리.
/// AppHeader에서 미읽음 배지 수를 표시하는 데 사용.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

/// 알림 상태 데이터
class NotificationState {
  final List<AppNotification> notifications;
  /// 미읽음 알림 수 (헤더 배지에 표시)
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 알림 Provider
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationServiceProvider));
});

/// 알림 상태 관리 Notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;

  NotificationNotifier(this._service) : super(const NotificationState());

  /// 알림 목록 전체 로드 + 미읽음 수 계산
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notifications = await _service.getNotifications();
      final unreadCount = notifications.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 개별 알림 읽음 처리 후 목록 리로드
  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    await loadNotifications();
  }

  /// 모든 알림 일괄 읽음 처리 후 목록 리로드
  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    await loadNotifications();
  }

  /// 미읽음 알림 수만 갱신 (가벼운 API 호출)
  Future<void> getUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }
}
