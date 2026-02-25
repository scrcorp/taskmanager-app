import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
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

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    await ref.read(taskProvider.notifier).completeTask(widget.id);
    if (mounted) {
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as complete'), backgroundColor: AppColors.success),
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
            Expanded(
              child: Center(
                child: Text(state.error ?? 'Task not found',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(task),
                    const SizedBox(height: 8),
                    _buildInfoSection(task),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDescriptionSection(task),
                    ],
                    if (task.assigneeNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildAssigneesSection(task),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Mark Complete Button
            if (task.status != 'completed')
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  color: AppColors.white,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _completing ? null : _markComplete,
                      child: _completing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Mark Complete'),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Header Card: title, priority, status ──
  Widget _buildHeaderCard(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority + Status row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _priorityBgColor(task.priority),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.priorityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _priorityColor(task.priority),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.status == 'completed'
                      ? AppColors.successBg
                      : task.status == 'in_progress'
                          ? AppColors.accentBg
                          : AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: task.status == 'completed'
                        ? AppColors.success
                        : task.status == 'in_progress'
                            ? AppColors.accent
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (task.storeName != null) ...[
            const SizedBox(height: 4),
            Text(
              task.storeName!,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Info Section: dates, creator ──
  Widget _buildInfoSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (task.dueDate != null)
            _DetailRow(
              icon: Icons.schedule,
              label: 'Due date',
              value: DateFormat('MMM d, h:mm a').format(task.dueDate!),
              valueColor: task.dueDate!.isBefore(DateTime.now()) && task.status != 'completed'
                  ? AppColors.danger
                  : null,
            ),
          if (task.dueDate != null && (task.assigneeNames.isNotEmpty || task.createdByName != null))
            const _SectionDivider(),
          if (task.assigneeNames.isNotEmpty)
            _DetailRow(
              icon: Icons.people_outline,
              label: 'Assigned to',
              value: task.assigneeNames.join(', '),
            ),
          if (task.assigneeNames.isNotEmpty && task.createdByName != null)
            const _SectionDivider(),
          if (task.createdByName != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Created by',
              value: task.createdByName!,
            ),
          if (task.createdAt != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Created at',
              value: DateFormat('MMM d, h:mm a').format(task.createdAt!),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description Section ──
  Widget _buildDescriptionSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            task.description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Assignees Section ──
  Widget _buildAssigneesSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignees (${task.assigneeNames.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...task.assigneeNames.map((name) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accentBg,
                    child: const Icon(Icons.person, size: 16, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Detail Row Widget ──
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Divider ──
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
    );
  }
}
