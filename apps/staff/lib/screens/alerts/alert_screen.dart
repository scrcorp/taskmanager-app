/// 알림(Alert) 목록 화면
///
/// 미읽음/읽음 알림을 카드 형태로 표시.
/// 미읽음 알림은 파란 점 + 강조 배경으로 구분.
/// 상단에 "Mark all read" 버튼으로 일괄 읽음 처리.
/// 탭 시 referenceType에 따라 해당 상세 화면으로 네비게이션
/// (work_assignment → 근무배정, additional_task → 업무, notice → 공지).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/alert_provider.dart';
import '../../widgets/app_header.dart';

/// 알림 목록 화면 위젯
class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({super.key});

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(alertProvider.notifier).loadAlerts());
  }

  void _navigateToReference(String? type, String? id) {
    if (type == null || id == null) return;
    // 서버가 보내는 reference_type 매핑.
    // cl_instances / cl_instance_items / checklist_review 모두 체크리스트 화면으로.
    switch (type) {
      case 'schedule':
      case 'work_assignment': // backward compat
        context.push('/work/$id');
      case 'additional_task':
        context.push('/tasks/$id');
      case 'notice':
        context.push('/notices/$id');
      case 'cl_instances':
      case 'cl_instance_items':
      case 'checklist_review':
        context.push('/work/$id');
      case 'daily_report':
        context.push('/daily-reports/$id');
      case 'attendance':
        // attendance correction 알림은 보통 GM/SV 대상.
        // app 내 attendance 상세 화면이 아직 없어 clock 화면으로 fallback.
        context.push('/clock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(alertProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: t.alertsHeader, isDetail: true, onBack: () => context.pop()),

          // Mark all read bar
          if (state.unreadCount > 0)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.alertsUnreadCount(state.unreadCount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => ref.read(alertProvider.notifier).markAllAsRead(),
                    child: Text(t.alertsMarkAllRead,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                ],
              ),
            ),

          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(AlertState state) {
    final t = AppL10n.of(context);
    if (state.isLoading && state.alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (state.error != null && state.alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                t.alertsLoadFailed,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(alertProvider.notifier).loadAlerts(),
                child: Text(t.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                t.alertsEmpty,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () =>
          ref.read(alertProvider.notifier).loadAlerts(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = state.alerts[index];
          return InkWell(
            onTap: () {
              if (!n.isRead) {
                ref.read(alertProvider.notifier).markAsRead(n.id);
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
    final t = AppL10n.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return t.timeJustNow;
    if (diff.inMinutes < 60) return t.timeMinAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.timeHourAgo(diff.inHours);
    if (diff.inDays == 1) return t.timeYesterday;
    if (diff.inDays < 7) return t.timeDayAgo(diff.inDays);
    if (diff.inDays < 30) return t.timeWeekAgo((diff.inDays / 7).floor());
    return DateFormat.yMMMd(localeStr).format(dt);
  }
}
