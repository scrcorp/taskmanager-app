/// 앱 헤더 위젯 — 모든 화면 상단에 표시
///
/// 구성: [프로필 아바타 / 뒤로가기] | [화면 제목] | [알림 아이콘 + 미읽음 배지]
///
/// 모드:
/// - 일반 모드 (isDetail=false): 좌측에 프로필 아바타 (탭 시 마이페이지)
/// - 상세 모드 (isDetail=true): 좌측에 뒤로가기 버튼
///
/// 알림 미읽음 수는 initState에서 자동 조회하여 배지로 표시.
/// 화면 제목은 현재 라우트 경로에서 자동 결정하거나 title 파라미터 사용.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/notification_provider.dart';

/// 앱 공통 헤더 — SafeArea + 52px 높이의 상단 바
class AppHeader extends ConsumerStatefulWidget {
  final String? title;
  /// true이면 상세 화면 모드 (뒤로가기 버튼 표시)
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
    // 미읽음 알림 수를 가볍게 조회 (배지 표시용)
    Future.microtask(() {
      ref.read(notificationProvider.notifier).getUnreadCount();
    });
  }

  /// 현재 라우트 경로에서 화면 제목을 결정
  String _getTitleFromLocation(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    switch (location) {
      case '/home': return 'Home';
      case '/work': return 'mytask';
      case '/tasks': return 'Tasks';
      case '/notices': return 'Notices';
      case '/clock': return 'Clock In Out';
      case '/schedule': return 'Schedule';
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
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 좌측: 프로필 아바타 또는 뒤로가기
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
            // 중앙: 화면 제목
            Expanded(
              child: Text(
                _getTitleFromLocation(context),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 우측: 알림 아이콘 + 미읽음 배지
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
