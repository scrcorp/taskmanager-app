import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_header.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationProvider.notifier).loadNotifications());
  }

  void _navigateToReference(String? type, String? id) {
    if (type == null || id == null) return;
    switch (type) {
      case 'work_assignment':
        context.push('/work/$id');
      case 'additional_task':
        context.push('/tasks/$id');
      case 'announcement':
        context.push('/notices/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: 'Notifications', isDetail: true, onBack: () => context.pop()),

          // Mark all read button
          if (state.unreadCount > 0)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${state.unreadCount} unread', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => ref.read(notificationProvider.notifier).markAllAsRead(),
                    child: Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('No notifications', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(notificationProvider.notifier).loadNotifications(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = state.notifications[i];
                            return GestureDetector(
                              onTap: () {
                                if (!n.isRead) {
                                  ref.read(notificationProvider.notifier).markAsRead(n.id);
                                }
                                _navigateToReference(n.referenceType, n.referenceId);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: n.isRead ? AppColors.white : AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: n.isRead ? AppColors.border : AppColors.accent.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: n.isRead ? Colors.transparent : AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(n.createdAt),
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (n.referenceType != null)
                                      Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
