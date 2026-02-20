import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/notification_provider.dart';

class AppHeader extends ConsumerStatefulWidget {
  final String? title;
  final bool isDetail;
  final VoidCallback? onBack;

  const AppHeader({super.key, this.title, this.isDetail = false, this.onBack});

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationProvider.notifier).getUnreadCount();
    });
  }

  String _getTitleFromLocation(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    switch (location) {
      case '/home': return 'Home';
      case '/work': return 'Checklist';
      case '/tasks': return 'Tasks';
      case '/notices': return 'Notices';
      default: return widget.title ?? 'TaskManager';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(notificationProvider).unreadCount;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Left
            SizedBox(
              width: 40,
              child: widget.isDetail
                ? IconButton(
                    icon: const Icon(Icons.chevron_left, size: 28),
                    onPressed: widget.onBack ?? () => context.pop(),
                    padding: EdgeInsets.zero,
                  )
                : GestureDetector(
                    onTap: () => context.push('/my'),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentBg,
                      child: Icon(Icons.person, size: 16, color: AppColors.accent),
                    ),
                  ),
            ),
            // Center
            Expanded(
              child: Text(
                _getTitleFromLocation(context),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Right
            SizedBox(
              width: 40,
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 22, color: AppColors.textSecondary),
                    onPressed: () => context.push('/alerts'),
                    padding: EdgeInsets.zero,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
