import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/checklist.dart';
import '../../providers/assignment_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

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
    Future.microtask(() => ref.read(assignmentProvider.notifier).loadAssignment(widget.id));
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All tasks completed! Great work!');
  }

  void _onItemTap(ChecklistItem item) {
    if (item.isCompleted) return;
    ref.read(assignmentProvider.notifier).toggleChecklistItem(
      widget.id, item.index, !item.isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentProvider);
    final assignment = state.selected;

    // Show toast when all completed
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
      body: Column(
        children: [
          AppHeader(
            title: assignment?.store.name ?? 'Checklist',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          if (state.isLoading && assignment == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && assignment == null)
            Expanded(
              child: Center(
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
                          ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (assignment == null)
            const Expanded(child: Center(child: Text('Assignment not found')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
                              final item = assignment.checklistSnapshot!.items[index];
                              return Column(
                                children: [
                                  if (index > 0)
                                    const Divider(height: 1, color: AppColors.border),
                                  _ChecklistItemTile(
                                    item: item,
                                    onTap: () => _onItemTap(item),
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
            ),
        ],
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
  final ChecklistItem item;
  final VoidCallback onTap;

  const _ChecklistItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                  color: item.isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isCompleted ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.isCompleted
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
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: item.isCompleted ? AppColors.textMuted : AppColors.text,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                  if (item.isCompleted && item.completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Done ${item.completedAtDisplay}${item.completedBy != null ? ' · ${item.completedBy}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.success),
                    ),
                  ],
                ],
              ),
            ),
            // Verification type icons
            if (item.requiresVerification && !item.isCompleted) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  if (item.requiresComment)
                    Icon(Icons.edit_note, size: 18, color: AppColors.accent.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
