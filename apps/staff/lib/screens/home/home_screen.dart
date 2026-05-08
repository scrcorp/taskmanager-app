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
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/notice_provider.dart';
import '../../providers/voice_provider.dart';
import '../../models/notice.dart';
import 'widgets/schedule_summary_card.dart';

/// 의견 제출 카테고리 라벨 (locale에 따라 동적 생성)
Map<String, String> _voiceCategoriesFor(AppL10n t) => {
      'idea': t.homeVoiceCategoryIdea,
      'facility': t.homeVoiceCategoryFacility,
      'safety': t.homeVoiceCategorySafety,
      'hr': t.homeVoiceCategoryHr,
      'other': t.homeVoiceCategoryOther,
    };

/// 현재 시간대에 맞는 인사말 반환
String _getGreeting(AppL10n t) {
  final hour = DateTime.now().hour;
  if (hour < 12) return t.homeGreetingMorning;
  if (hour < 17) return t.homeGreetingAfternoon;
  return t.homeGreetingEvening;
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
  /// must_change_password 배너 dismiss 상태 (로컬)
  bool _passwordBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // No date param → server determines "today" per store timezone
      ref.read(myScheduleProvider.notifier).loadSchedules();
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(noticeProvider.notifier).loadNotices();
    });
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitVoice() async {
    final t = AppL10n.of(context);
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
      await AppModal.show(
        context,
        title: t.homeVoiceSubmittedTitle,
        message: t.homeVoiceSubmittedMessage,
        type: ModalType.success,
      );
    } else {
      await AppModal.show(
        context,
        title: t.homeVoiceFailedTitle,
        message: t.homeVoiceFailedMessage,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final user = ref.watch(authProvider).user;
    final scheduleState = ref.watch(myScheduleProvider);
    final tasks = ref.watch(taskProvider);
    final notices = ref.watch(noticeProvider);
    final today = DateTime.now();

    final firstName = user?.firstName ?? t.commonStaff;
    final fullName = user?.fullName ?? t.commonStaff;
    final dueTodayCount = _countDueToday(tasks.tasks);
    final checklistSchedules =
        scheduleState.schedules.where((s) => s.totalItems > 0).toList();
    final totalSchedules = checklistSchedules.length;
    final completedSchedules = checklistSchedules.where((s) {
      return s.completedItems == s.totalItems;
    }).length;
    final totalTasks = tasks.tasks.length;
    final completedTasks = tasks.tasks.where((t) => t.status == 'completed').length;
    final noticeCount = notices.notices.length;

    final mustChangePw = (user?.mustChangePassword ?? false) && !_passwordBannerDismissed;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await Future.wait([
          ref.read(myScheduleProvider.notifier).loadSchedules(),
          ref.read(taskProvider.notifier).loadTasks(),
          ref.read(noticeProvider.notifier).loadNotices(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Password change suggestion banner ──
          if (mustChangePw)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('\u26A0\uFE0F', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.homePasswordBannerMessage,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/my/change-password'),
                      child: Text(t.actionChange, style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _passwordBannerDismissed = true),
                      child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
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
                  '${_getGreeting(t)},',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$firstName${t.homeFirstNameSuffix}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMEd(localeStr).format(today),
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
                  Text(
                    t.homeTodayOverview,
                    style: const TextStyle(
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
                        label: t.homeStatChecklist,
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
                        label: t.homeStatTasks,
                        value: tasks.isLoading
                            ? '-'
                            : '$completedTasks/$totalTasks',
                        color: totalTasks > 0 && completedTasks == totalTasks
                            ? AppColors.success
                            : AppColors.accent,
                      ),
                      _statDivider(),
                      _StatItem(
                        label: t.homeStatDueToday,
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
                    label: t.homeQuickNotices,
                    badge: noticeCount > 0 ? noticeCount : null,
                    onTap: () => context.push('/notices'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.school_rounded,
                    label: t.homeQuickOjt,
                    onTap: () => context.push('/ojt'),
                  ),
                ),
              ],
            ),
          ),
          if (user?.hasPermission('daily_reports:read') ?? false) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _QuickActionCard(
                icon: Icons.summarize_rounded,
                label: t.homeQuickDailyReports,
                onTap: () => context.push('/daily-reports'),
              ),
            ),
          ],
          // ── Inventory quick action (SV+ only — need create, not just read) ──
          if (user != null && user.hasPermission('inventory:create')) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _QuickActionCard(
                icon: Icons.inventory_2_rounded,
                label: t.homeQuickInventory,
                onTap: () => context.push('/inventory'),
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
                            items: _voiceCategoriesFor(t).entries.map((e) {
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
                            decoration: InputDecoration(
                              hintText: t.homeVoiceHint,
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
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
          if (notices.notices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ImportantNoticeBanner(
                notice: notices.notices.first,
                onTap: () => context.push('/notices/${notices.notices.first.id}'),
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
  final Notice notice;
  final VoidCallback onTap;

  const _ImportantNoticeBanner({
    required this.notice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final localeStr = Localizations.localeOf(context).toString();
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.campaign_rounded, size: 13, color: Color(0xFFFF9B9B)),
                      const SizedBox(width: 4),
                      Text(
                        t.homeImportantNotice,
                        style: const TextStyle(
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
                if (notice.createdAt != null)
                  Text(
                    DateFormat.Md(localeStr).format(notice.createdAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notice.title,
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
              notice.content,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.homeViewDetails,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
