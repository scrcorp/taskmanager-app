import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/announcement_provider.dart';

String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _ideaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignments(today);
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(announcementProvider.notifier).loadAnnouncements();
    });
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    super.dispose();
  }

  void _submitIdea() {
    final text = _ideaCtrl.text.trim();
    if (text.isEmpty) return;
    _ideaCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for sharing!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final assignments = ref.watch(assignmentProvider);
    final tasks = ref.watch(taskProvider);
    final announcements = ref.watch(announcementProvider);
    final today = DateTime.now();

    final firstName = user?.firstName ?? 'Staff';
    final fullName = user?.fullName ?? 'Staff';
    final dueTodayCount = _countDueToday(tasks.tasks);
    final totalAssignments = assignments.assignments.length;
    final completedAssignments = assignments.assignments.where((a) {
      final snap = a.checklistSnapshot;
      return snap != null && snap.totalItems > 0 && snap.completedItems == snap.totalItems;
    }).length;
    final totalTasks = tasks.tasks.length;
    final completedTasks = tasks.tasks.where((t) => t.status == 'completed').length;
    final noticeCount = announcements.announcements.length;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        final dateStr = DateFormat('yyyy-MM-dd').format(today);
        await Future.wait([
          ref.read(assignmentProvider.notifier).loadAssignments(dateStr),
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
                        value: assignments.isLoading
                            ? '-'
                            : '$completedAssignments/$totalAssignments',
                        color: totalAssignments > 0 && completedAssignments == totalAssignments
                            ? AppColors.success
                            : AppColors.accent,
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

          // ── Quick actions (Notices + OJT) ──
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
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon'),
                        duration: Duration(seconds: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
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
                              hintText: 'Share your idea!',
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
                            onSubmitted: (_) => _submitIdea(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _submitIdea,
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

          // ── Featured content banner ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const _FeaturedBanner(
              title: 'Better Workplace,\nBetter Life.',
              subtitle: 'Tips for a productive day',
              ctaText: 'Read more',
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

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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

// ─── Featured content banner ────────────────────────────────────────────────

class _FeaturedBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String ctaText;

  const _FeaturedBanner({
    required this.title,
    required this.subtitle,
    required this.ctaText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(minHeight: 320),
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'FEATURED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                ctaText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}
