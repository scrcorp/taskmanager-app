import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';
import '../../widgets/app_header.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTask(widget.id));
  }

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    await ref.read(taskProvider.notifier).completeTask(widget.id);
    if (mounted) {
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed!'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final task = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: 'Task Detail', isDetail: true, onBack: () => context.pop()),
          if (state.isLoading && task == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (task == null)
            const Expanded(child: Center(child: Text('Task not found')))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + priority
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (task.priority == 'urgent' || task.priority == 'high')
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(task.priorityLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: task.status == 'completed' ? AppColors.successBg : AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(task.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: task.status == 'completed' ? AppColors.success : AppColors.accent)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(task.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                          if (task.description != null && task.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(task.description!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          if (task.storeName != null) _InfoRow(icon: Icons.store, label: 'Store', value: task.storeName!),
                          if (task.createdByName != null) _InfoRow(icon: Icons.person, label: 'Created by', value: task.createdByName!),
                          if (task.dueDate != null) _InfoRow(icon: Icons.schedule, label: 'Due', value: DateFormat('MMM d, yyyy h:mm a').format(task.dueDate!)),
                          if (task.createdAt != null) _InfoRow(icon: Icons.calendar_today, label: 'Created', value: DateFormat('MMM d, yyyy').format(task.createdAt!)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Assignees
                    if (task.assigneeNames.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assignees', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 8),
                            ...task.assigneeNames.map((name) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 18, color: AppColors.textMuted),
                                  const SizedBox(width: 8),
                                  Text(name, style: TextStyle(fontSize: 14, color: AppColors.text)),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Complete button
                    if (task.status != 'completed')
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _completing ? null : _markComplete,
                          icon: _completing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Mark Complete'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AppColors.text))),
        ],
      ),
    );
  }
}
