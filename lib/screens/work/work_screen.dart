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

  void _shiftDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadForDate();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentProvider);
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Date selector
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, size: 24), onPressed: () => _shiftDate(-1)),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _loadForDate();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.accentBg : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isToday ? 'Today, ${DateFormat('MMM d').format(_selectedDate)}' : DateFormat('EEE, MMM d').format(_selectedDate),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isToday ? AppColors.accent : AppColors.text),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right, size: 24), onPressed: () => _shiftDate(1)),
              ],
            ),
          ),

          // Assignment list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.assignments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('No assignments', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadForDate(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.assignments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final a = state.assignments[i];
                            final progress = a.checklistSnapshot?.progress ?? 0;
                            return GestureDetector(
                              onTap: () => context.push('/work/${a.id}'),
                              child: Container(
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
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                                          child: Icon(Icons.store, size: 18, color: AppColors.accent),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(a.store.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                                              Text('${a.shift.name} · ${a.position.name}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: a.status == 'completed' ? AppColors.successBg : AppColors.accentBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(a.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: a.status == 'completed' ? AppColors.success : AppColors.accent)),
                                        ),
                                      ],
                                    ),
                                    if (a.checklistSnapshot != null) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: AppColors.border,
                                          color: progress >= 1.0 ? AppColors.success : AppColors.accent,
                                          minHeight: 5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${a.checklistSnapshot!.completedItems}/${a.checklistSnapshot!.totalItems} items · ${(progress * 100).round()}%',
                                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
