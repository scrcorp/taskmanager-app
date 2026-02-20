import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationState {
  final List<AppNotification> notifications;
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

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationServiceProvider));
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;

  NotificationNotifier(this._service) : super(const NotificationState());

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

  Future<void> markAsRead(String id) async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id && !n.isRead) {
          return AppNotification(
            id: n.id,
            type: n.type,
            message: n.message,
            referenceType: n.referenceType,
            referenceId: n.referenceId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );

    try {
      await _service.markAsRead(id);
    } catch (e) {
      // Revert on failure by reloading
      await loadNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (!n.isRead) {
          return AppNotification(
            id: n.id,
            type: n.type,
            message: n.message,
            referenceType: n.referenceType,
            referenceId: n.referenceId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList(),
      unreadCount: 0,
    );

    try {
      await _service.markAllAsRead();
    } catch (e) {
      // Revert on failure by reloading
      await loadNotifications();
    }
  }

  Future<void> getUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {
      // Silently fail - unread count is non-critical
    }
  }
}
