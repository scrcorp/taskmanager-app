import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/assignment_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});
  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
    });
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All tasks completed! Great work!');
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(assignmentProvider);
    final assignment = assignmentState.selected;

    // Check for all-completed state after build
    if (assignment != null &&
        assignment.checklistSnapshot != null &&
        assignment.checklistSnapshot!.isAllCompleted &&
        !_celebrationShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionToast();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Checklist'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: assignmentState.isLoading || assignment == null
          ? const Center(child: CircularProgressIndicator())
          : assignmentState.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Failed to load assignment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(assignmentProvider.notifier)
                                .loadAssignment(widget.id);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(assignmentProvider.notifier)
                        .loadAssignment(widget.id);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Assignment header card
                      Container(
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
                              assignment.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatFixedDateWithDay(assignment.workDate),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Progress section
                            _buildProgressSection(assignment),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Checklist items header
                      Row(
                        children: [
                          const Text(
                            'Checklist Items',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (assignment.checklistSnapshot != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${assignment.checklistSnapshot!.totalItems}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Checklist items
                      if (assignment.checklistSnapshot == null ||
                          assignment.checklistSnapshot!.items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No checklist items',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: List.generate(
                              assignment.checklistSnapshot!.items.length,
                              (index) {
                                final item =
                                    assignment.checklistSnapshot!.items[index];
                                return Column(
                                  children: [
                                    if (index > 0)
                                      const Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),
                                    _ChecklistItemTile(
                                      title: item.title,
                                      description: item.description,
                                      isCompleted: item.isCompleted,
                                      completedAtDisplay: item.completedAtDisplay,
                                      onToggle: () {
                                        ref
                                            .read(
                                                assignmentProvider.notifier)
                                            .toggleChecklistItem(
                                              widget.id,
                                              item.index,
                                              !item.isCompleted,
                                            );
                                      },
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
                ),
    );
  }

  Widget _buildProgressSection(assignment) {
    final snapshot = assignment.checklistSnapshot;
    final completed = snapshot?.completedItems ?? 0;
    final total = snapshot?.totalItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = progress >= 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isComplete ? 'Completed' : 'In Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isComplete ? AppColors.success : AppColors.accent,
              ),
            ),
            Text(
              '$completed/$total items',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
              isComplete ? AppColors.success : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  final String title;
  final String? description;
  final bool isCompleted;
  final String? completedAtDisplay;
  final VoidCallback onToggle;

  const _ChecklistItemTile({
    required this.title,
    this.description,
    required this.isCompleted,
    this.completedAtDisplay,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? AppColors.textMuted
                          : AppColors.text,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (isCompleted && completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed $completedAtDisplay',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
