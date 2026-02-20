import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../utils/date_utils.dart' as date_utils;

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
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(announcementProvider.notifier).loadAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final assignments = ref.watch(assignmentProvider);
    final tasks = ref.watch(taskProvider);
    final announcements = ref.watch(announcementProvider);
    final today = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        final dateStr = DateFormat('yyyy-MM-dd').format(today);
        await Future.wait([
          ref.read(assignmentProvider.notifier).loadAssignments(dateStr),
          ref.read(taskProvider.notifier).loadTasks(),
          ref.read(announcementProvider.notifier).loadAnnouncements(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting
          Text(
            'Hello, ${user?.fullName ?? 'Staff'}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(today),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Today's Work section
          _SectionHeader(
            title: "Today's Work",
            count: assignments.assignments.length,
          ),
          const SizedBox(height: 12),
          if (assignments.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (assignments.assignments.isEmpty)
            const _EmptyCard(message: 'No assignments for today')
          else
            ...assignments.assignments.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  label: a.label,
                  completed: a.checklistSnapshot?.completedItems ?? 0,
                  total: a.checklistSnapshot?.totalItems ?? 0,
                  status: a.statusLabel,
                  onTap: () => context.push('/work/${a.id}'),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Additional Tasks section
          _SectionHeader(
            title: 'Tasks',
            count: tasks.tasks.length,
          ),
          const SizedBox(height: 12),
          if (tasks.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (tasks.tasks.isEmpty)
            const _EmptyCard(message: 'No additional tasks')
          else
            ...tasks.tasks.take(3).map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(
                  title: t.title,
                  store: t.store?.name,
                  priority: t.priority,
                  dueDate: t.dueDate,
                  status: t.statusLabel,
                  onTap: () => context.push('/tasks/${t.id}'),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Recent Notices section
          const _SectionHeader(title: 'Recent Notices'),
          const SizedBox(height: 12),
          if (announcements.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (announcements.announcements.isEmpty)
            const _EmptyCard(message: 'No notices')
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: List.generate(
                  announcements.announcements.take(3).length,
                  (index) {
                    final n = announcements.announcements[index];
                    return Column(
                      children: [
                        if (index > 0)
                          const Divider(height: 1, color: AppColors.border),
                        InkWell(
                          onTap: () => context.push('/notices/${n.id}'),
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottom: index ==
                                    announcements.announcements.take(3).length -
                                        1
                                ? const Radius.circular(12)
                                : Radius.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                if (n.createdAt != null)
                                  Text(
                                    date_utils.timeAgo(n.createdAt!),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String label;
  final int completed;
  final int total;
  final String status;
  final VoidCallback onTap;
  const _AssignmentCard({
    required this.label,
    required this.completed,
    required this.total,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'Completed'
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
                Text(
                  '$completed/$total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String? store;
  final String priority;
  final DateTime? dueDate;
  final String status;
  final VoidCallback onTap;
  const _TaskCard({
    required this.title,
    this.store,
    required this.priority,
    this.dueDate,
    required this.status,
    required this.onTap,
  });

  Color get _priorityColor {
    switch (priority) {
      case 'urgent':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  IconData get _priorityIcon {
    switch (priority) {
      case 'urgent':
        return Icons.circle;
      case 'high':
        return Icons.circle;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (store != null) subtitleParts.add(store!);
    if (dueDate != null) {
      subtitleParts.add('Due: ${date_utils.formatFixedDate(dueDate!)}');
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_priorityIcon, size: 10, color: _priorityColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 11,
                color: status == 'Completed'
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
