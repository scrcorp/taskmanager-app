import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../utils/date_utils.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});
  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final filtered = _filter == 'all'
        ? state.tasks
        : state.tasks.where((t) => t.status == _filter).toList();

    return Column(
      children: [
        // Filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text('Filter: ',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _filter,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? 'all'),
                ),
              ),
            ],
          ),
        ),
        // Task list
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No tasks',
                          style: TextStyle(color: AppColors.textMuted)))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(taskProvider.notifier).loadTasks(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _TaskCard(task: filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AdditionalTask task;
  const _TaskCard({required this.task});

  Color get _priorityColor {
    switch (task.priority) {
      case 'urgent':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/tasks/${task.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: task.status == 'completed'
                    ? const Icon(Icons.check_circle,
                        size: 14, color: AppColors.success)
                    : Icon(Icons.circle, size: 10, color: _priorityColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(task.store?.name ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (task.dueDate != null)
                          Text(
                              'Due: ${formatFixedDate(task.dueDate!)}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        Text(task.statusLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: task.status == 'completed'
                                    ? AppColors.success
                                    : AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
