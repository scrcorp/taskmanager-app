import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: state.isLoading && state.tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No tasks assigned', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final task = state.tasks[i];
                      final isUrgent = task.priority == 'urgent' || task.priority == 'high';

                      return GestureDetector(
                        onTap: () => context.push('/tasks/${task.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isUrgent ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isUrgent) ...[
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(task.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  _StatusBadge(status: task.status),
                                ],
                              ),
                              if (task.description != null && task.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(task.description!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (task.store != null) ...[
                                    Icon(Icons.store, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(task.store!.name, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    const SizedBox(width: 12),
                                  ],
                                  if (task.dueDate != null) ...[
                                    Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(DateFormat('MMM d, h:mm a').format(task.dueDate!), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'completed':
        bg = AppColors.successBg;
        fg = AppColors.success;
        label = 'Done';
      case 'in_progress':
        bg = AppColors.accentBg;
        fg = AppColors.accent;
        label = 'In Progress';
      default:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
