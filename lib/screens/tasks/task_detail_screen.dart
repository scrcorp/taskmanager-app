import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTask(widget.id));
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'normal':
        return AppColors.accent;
      case 'low':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  Color _priorityBgColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.dangerBg;
      case 'high':
        return AppColors.warningBg;
      case 'normal':
        return AppColors.accentBg;
      case 'low':
        return AppColors.bg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final task = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Additional Tasks'),
      ),
      body: state.isLoading && task == null
          ? const Center(child: CircularProgressIndicator())
          : task == null
              ? Center(
                  child: Text(state.error ?? 'Task not found',
                      style: const TextStyle(color: AppColors.textMuted)),
                )
              : _buildContent(task, state.isLoading),
    );
  }

  Widget _buildContent(AdditionalTask task, bool isLoading) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + priority badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(task.title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priorityBgColor(task.priority),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(task.priorityLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _priorityColor(task.priority))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Store
                if (task.store?.name != null)
                  Text(task.store!.name,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                // Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.status == 'completed'
                            ? AppColors.successBg
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: task.status == 'completed'
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                      child: Text(task.statusLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: task.status == 'completed'
                                  ? AppColors.success
                                  : AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Due date
                if (task.dueDate != null) ...[
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Due Date',
                    value: formatFixedDate(task.dueDate!),
                  ),
                  const SizedBox(height: 10),
                ],

                // Created by
                if (task.createdByName != null) ...[
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Created by',
                    value: task.createdByName!,
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 8),

                // Description
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(task.description!,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.text)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Assignees
                if (task.assignees.isNotEmpty) ...[
                  const Text('Assignees',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: List.generate(task.assignees.length, (i) {
                        final assignee = task.assignees[i];
                        return Column(
                          children: [
                            if (i > 0)
                              const Divider(
                                  height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    assignee.isCompleted
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: assignee.isCompleted
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      assignee.fullName ?? 'Unknown',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.text),
                                    ),
                                  ),
                                  if (assignee.isCompleted &&
                                      assignee.completedAt != null)
                                    Text(
                                      formatActionTime(assignee.completedAt!),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Mark Complete button
        if (task.status != 'completed')
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          await ref
                              .read(taskProvider.notifier)
                              .completeTask(widget.id);
                          if (mounted) {
                            ToastManager().success(context, 'Task marked as complete');
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('Mark Complete'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: AppColors.text)),
        ),
      ],
    );
  }
}
