/// 홈 화면 — 직원 앱의 메인 대시보드
///
/// 상단: 인사말 + 날짜 헤더
/// 중간: 오늘의 Overview (체크리스트/태스크/마감 통계)
/// 퀵 액션: 공지사항, OJT 바로가기
/// 하단: 의견 제출(Voice) 입력란 + 최신 공지 배너
///
/// initState에서 오늘 근무배정, 추가 업무, 공지사항을 병렬 로드.
/// pull-to-refresh로 데이터 새로고침 지원.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/voice_provider.dart';
import '../../models/announcement.dart';
import '../../utils/toast_manager.dart';
import 'widgets/schedule_summary_card.dart';

/// 의견 제출 카테고리 맵 (키: API 값, 값: 표시 라벨)
const _voiceCategories = <String, String>{
  'idea': '\u{1F4A1} Idea',
  'facility': '\u{1F527} Facility',
  'safety': '\u{26A0}\u{FE0F} Safety',
  'hr': '\u{1F464} HR',
  'other': '\u{1F4CB} Other',
};

/// 현재 시간대에 맞는 인사말 반환
String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// 오늘 마감인 미완료 태스크 수 계산
int _countDueToday(List<AdditionalTask> tasks) {
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.year == now.year &&
        t.dueDate!.month == now.month &&
        t.dueDate!.day == now.day &&
        t.status != 'completed';
  }).length;
}

/// 홈 화면 메인 위젯
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _ideaCtrl = TextEditingController();
  String _selectedCategory = 'idea';

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(myScheduleProvider.notifier).loadSchedules(today);
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(announcementProvider.notifier).loadAnnouncements();
    });
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitVoice() async {
    final text = _ideaCtrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(voiceProvider.notifier).submitVoice(
          content: text,
          category: _selectedCategory,
        );
    if (!mounted) return;
    if (ok) {
      _ideaCtrl.clear();
      ToastManager().success(context, 'Thanks for sharing!');
    } else {
      ToastManager().error(context, 'Failed to submit. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final scheduleState = ref.watch(myScheduleProvider);
    final tasks = ref.watch(taskProvider);
    final announcements = ref.watch(announcementProvider);
    final today = DateTime.now();

    final firstName = user?.firstName ?? 'Staff';
    final fullName = user?.fullName ?? 'Staff';
    final dueTodayCount = _countDueToday(tasks.tasks);
    final checklistSchedules =
        scheduleState.schedules.where((s) => s.totalItems > 0).toList();
    final totalSchedules = checklistSchedules.length;
    final completedSchedules = checklistSchedules.where((s) {
      return s.completedItems == s.totalItems;
    }).length;
    final totalTasks = tasks.tasks.length;
    final completedTasks = tasks.tasks.where((t) => t.status == 'completed').length;
    final noticeCount = announcements.announcements.length;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        final dateStr = DateFormat('yyyy-MM-dd').format(today);
        await Future.wait([
          ref.read(myScheduleProvider.notifier).loadSchedules(dateStr),
          ref.read(taskProvider.notifier).loadTasks(),
          ref.read(announcementProvider.notifier).loadAnnouncements(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Greeting Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()},',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$firstName.',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy. MM. dd (E)').format(today),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Overview stats ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Overview",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatItem(
                        label: 'Checklist',
                        value: scheduleState.isLoading
                            ? '-'
                            : '$completedSchedules/$totalSchedules',
                        color: totalSchedules > 0 && completedSchedules == totalSchedules
                            ? AppColors.success
                            : AppColors.accent,
                        onTap: () => context.go('/work'),
                      ),
                      _statDivider(),
                      _StatItem(
                        label: 'Tasks',
                        value: tasks.isLoading
                            ? '-'
                            : '$completedTasks/$totalTasks',
                        color: totalTasks > 0 && completedTasks == totalTasks
                            ? AppColors.success
                            : AppColors.accent,
                      ),
                      _statDivider(),
                      _StatItem(
                        label: 'Due Today',
                        value: tasks.isLoading ? '-' : '$dueTodayCount',
                        color: dueTodayCount > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Schedule summary ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ScheduleSummaryCard(
              onViewAll: () => context.push('/schedule'),
              onResubmit: () => context.push('/schedule'),
            ),
          ),
          const SizedBox(height: 16),

          // ── Quick actions (Notices + OJT + Daily Reports) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.campaign_rounded,
                    label: 'Notices',
                    badge: noticeCount > 0 ? noticeCount : null,
                    onTap: () => context.push('/notices'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.school_rounded,
                    label: 'OJT',
                    onTap: () => context.push('/ojt'),
                  ),
                ),
              ],
            ),
          ),
          if ((user?.roleLevel ?? 40) <= 30) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _QuickActionCard(
                icon: Icons.summarize_rounded,
                label: 'Daily Reports',
                onTap: () => context.push('/daily-reports'),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // ── Share your idea ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentBg,
                        child: Text(
                          user?.initials ?? 'ST',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isDense: true,
                            style: const TextStyle(fontSize: 13, color: AppColors.text),
                            icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
                            items: _voiceCategories.entries.map((e) {
                              return DropdownMenuItem(value: e.key, child: Text(e.value));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedCategory = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ideaCtrl,
                            style: const TextStyle(fontSize: 14, color: AppColors.text),
                            decoration: const InputDecoration(
                              hintText: 'Share your voice!',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _submitVoice(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _submitVoice,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Important notice banner ──
          if (announcements.announcements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ImportantNoticeBanner(
                announcement: announcements.announcements.first,
                onTap: () => context.push('/notices/${announcements.announcements.first.id}'),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.border,
    );
  }
}

// ─── Stat item ──────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick action card ──────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (badge == null)
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Important notice banner ────────────────────────────────────────────────

class _ImportantNoticeBanner extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onTap;

  const _ImportantNoticeBanner({
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_rounded, size: 13, color: Color(0xFFFF9B9B)),
                      SizedBox(width: 4),
                      Text(
                        'IMPORTANT NOTICE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9B9B),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (announcement.createdAt != null)
                  Text(
                    DateFormat('MM/dd').format(announcement.createdAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              announcement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              announcement.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
