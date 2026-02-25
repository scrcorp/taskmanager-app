import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/assignment_provider.dart';
import '../../widgets/app_header.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(assignmentProvider.notifier).loadAssignment(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentProvider);
    final assignment = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: assignment?.store.name ?? 'Checklist', isDetail: true, onBack: () => context.pop()),
          if (state.isLoading && assignment == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (assignment == null)
            const Expanded(child: Center(child: Text('Assignment not found')))
          else ...[
            // Progress header
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${assignment.shift.name} · ${assignment.position.name}',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: assignment.checklistSnapshot?.progress ?? 0,
                            backgroundColor: AppColors.border,
                            color: (assignment.checklistSnapshot?.isAllCompleted ?? false) ? AppColors.success : AppColors.accent,
                            minHeight: 7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${assignment.checklistSnapshot?.completedItems ?? 0}/${assignment.checklistSnapshot?.totalItems ?? 0}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Checklist items
            Expanded(
              child: assignment.checklistSnapshot == null || assignment.checklistSnapshot!.items.isEmpty
                  ? const Center(child: Text('No checklist items'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: assignment.checklistSnapshot!.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = assignment.checklistSnapshot!.items[i];
                        return GestureDetector(
                          onTap: () async {
                            await ref.read(assignmentProvider.notifier).toggleChecklistItem(
                              widget.id, item.index, !item.isCompleted,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: item.isCompleted ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: item.isCompleted ? AppColors.success : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: item.isCompleted ? AppColors.success : AppColors.textMuted, width: 2),
                                  ),
                                  child: item.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600,
                                          color: item.isCompleted ? AppColors.textMuted : AppColors.text,
                                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(item.description!, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        ),
                                      if (item.completedAtDisplay != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text(item.completedAtDisplay!, style: TextStyle(fontSize: 11, color: AppColors.success)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (item.requiresPhoto)
                                  Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
