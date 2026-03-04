/// 알림(Notification) 목록 화면
///
/// 미읽음/읽음 알림을 카드 형태로 표시.
/// 미읽음 알림은 파란 점 + 강조 배경으로 구분.
/// 상단에 "Mark all read" 버튼으로 일괄 읽음 처리.
/// 탭 시 referenceType에 따라 해당 상세 화면으로 네비게이션
/// (work_assignment → 근무배정, additional_task → 업무, announcement → 공지).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_header.dart';

/// 알림 목록 화면 위젯
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
          AppHeader(title: 'Alerts', isDetail: true, onBack: () => context.pop()),

          // Mark all read bar
          if (state.unreadCount > 0)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${state.unreadCount} unread',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => ref.read(notificationProvider.notifier).markAllAsRead(),
                    child: const Text('Mark all read',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                ],
              ),
            ),

          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Failed to load notifications',
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(notificationProvider.notifier).loadNotifications(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none,
                  size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'No notifications yet',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () =>
          ref.read(notificationProvider.notifier).loadNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = state.notifications[index];
          return InkWell(
            onTap: () {
              if (!n.isRead) {
                ref.read(notificationProvider.notifier).markAsRead(n.id);
              }
              _navigateToReference(n.referenceType, n.referenceId);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: n.isRead ? AppColors.white : AppColors.accentBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: n.isRead ? AppColors.border : AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread indicator dot
                  if (!n.isRead)
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 10),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(width: 18),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgo(n.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (n.referenceType != null)
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }
}
