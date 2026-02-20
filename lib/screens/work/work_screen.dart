import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/assignment_provider.dart';

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});
  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadForDate();
  }

  void _loadForDate() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    ref.read(assignmentProvider.notifier).loadAssignments(dateStr);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadForDate();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(assignmentProvider);

    return RefreshIndicator(
      onRefresh: () async {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        await ref.read(assignmentProvider.notifier).loadAssignments(dateStr);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Date navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeDate(-1),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _loadForDate();
                    }
                  },
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isToday
                            ? 'Today, ${DateFormat('MMM d').format(_selectedDate)}'
                            : DateFormat('MMM d, yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: _isToday
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight:
                              _isToday ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _changeDate(1),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Assignment count header
          Row(
            children: [
              const Text(
                'Assignments',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              if (!assignmentState.isLoading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${assignmentState.assignments.length}',
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

          // Assignment list
          if (assignmentState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (assignmentState.error != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Failed to load assignments',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadForDate,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (assignmentState.assignments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No assignments for this date',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ...assignmentState.assignments.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkAssignmentCard(
                  label: a.label,
                  completed: a.checklistSnapshot?.completedItems ?? 0,
                  total: a.checklistSnapshot?.totalItems ?? 0,
                  status: a.statusLabel,
                  statusRaw: a.status,
                  onTap: () => context.push('/work/${a.id}'),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WorkAssignmentCard extends StatelessWidget {
  final String label;
  final int completed;
  final int total;
  final String status;
  final String statusRaw;
  final VoidCallback onTap;

  const _WorkAssignmentCard({
    required this.label,
    required this.completed,
    required this.total,
    required this.status,
    required this.statusRaw,
    required this.onTap,
  });

  Color get _statusColor {
    switch (statusRaw) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.accent;
      default:
        return AppColors.textMuted;
    }
  }

  Color get _statusBgColor {
    switch (statusRaw) {
      case 'completed':
        return AppColors.successBg;
      case 'in_progress':
        return AppColors.accentBg;
      default:
        return AppColors.bg;
    }
  }

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  total > 0 ? 'Checklist progress' : 'No checklist',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '$completed/$total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
