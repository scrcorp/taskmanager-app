import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignments(today);
      ref.read(announcementProvider.notifier).loadAnnouncements();
      ref.read(notificationProvider.notifier).getUnreadCount();
      ref.read(taskProvider.notifier).loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(assignmentProvider);
    final announcements = ref.watch(announcementProvider);
    final tasks = ref.watch(taskProvider);
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await Future.wait([
            ref.read(assignmentProvider.notifier).loadAssignments(today),
            ref.read(announcementProvider.notifier).loadAnnouncements(),
            ref.read(taskProvider.notifier).loadTasks(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              Row(
                children: [
                  _SummaryCard(
                    icon: Icons.assignment,
                    label: "Today's Work",
                    count: assignments.assignments.length,
                    color: AppColors.accent,
                    onTap: () => context.go('/work'),
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    icon: Icons.task,
                    label: 'Tasks',
                    count: tasks.tasks.where((t) => t.status != 'completed').length,
                    color: AppColors.warning,
                    onTap: () => context.go('/tasks'),
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    icon: Icons.notifications,
                    label: 'Unread',
                    count: notifications.unreadCount,
                    color: AppColors.danger,
                    onTap: () => context.push('/alerts'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Today's assignments
              _SectionHeader(title: "Today's Work", onSeeAll: () => context.go('/work')),
              const SizedBox(height: 8),
              if (assignments.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (assignments.assignments.isEmpty)
                _EmptyCard(message: 'No assignments for today')
              else
                ...assignments.assignments.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AssignmentCard(
                    label: a.label,
                    status: a.statusLabel,
                    progress: a.checklistSnapshot?.progress ?? 0,
                    onTap: () => context.push('/work/${a.id}'),
                  ),
                )),

              const SizedBox(height: 20),

              // Recent notices
              _SectionHeader(title: 'Recent Notices', onSeeAll: () => context.go('/notices')),
              const SizedBox(height: 8),
              if (announcements.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (announcements.announcements.isEmpty)
                _EmptyCard(message: 'No announcements')
              else
                ...announcements.announcements.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NoticeCard(
                    title: a.title,
                    author: a.createdByName ?? '',
                    date: a.createdAt,
                    onTap: () => context.push('/notices/${a.id}'),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _SummaryCard({required this.icon, required this.label, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        GestureDetector(
          onTap: onSeeAll,
          child: Text('See all', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String label;
  final String status;
  final double progress;
  final VoidCallback onTap;
  const _AssignmentCard({required this.label, required this.status, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'Completed' ? AppColors.successBg : AppColors.accentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status == 'Completed' ? AppColors.success : AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                color: progress >= 1.0 ? AppColors.success : AppColors.accent,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text('${(progress * 100).round()}% complete', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String author;
  final DateTime? date;
  final VoidCallback onTap;
  const _NoticeCard({required this.title, required this.author, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$author${date != null ? ' · ${DateFormat('MM/dd').format(date!)}' : ''}',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
    );
  }
}
