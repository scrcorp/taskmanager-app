/// 근무(Work) 화면 — 하단 네비게이션의 "My Task" 탭
///
/// 구성:
/// - 프로필 카드: 사용자 이름/역할/조직 + 오늘 배정된 매장/시프트 태그
/// - 체크리스트 섹션: Today/Past 탭 전환
///   - Today: 오늘 근무배정 카드 목록 (매장명, 시프트, 진행률)
///   - Past: 과거 30일 근무배정 (페이지네이션)
/// - 추가 업무(Task) 섹션: 검색/날짜필터/정렬 + 진행률 바 + 업무 카드 목록
///
/// 체크리스트 카드 탭 시 ChecklistScreen으로 이동하거나
/// 바텀시트로 간단한 체크리스트 표시.
/// scrollTo 쿼리 파라미터로 특정 섹션으로 자동 스크롤 가능.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/my_schedule.dart';
import '../../models/checklist.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_schedule_provider.dart';
import '../../providers/task_provider.dart';
import 'checklist_chat_screen.dart';
import '../../services/storage_service.dart';
import '../../utils/toast_manager.dart';

/// 근무 화면 메인 위젯 — Today/Past 체크리스트 + 추가 업무
class WorkScreen extends ConsumerStatefulWidget {
  final String? initialTab; // "past" → Past 탭으로 시작
  final String? scheduleId; // 특정 스케줄의 체크리스트 자동 열기

  const WorkScreen({super.key, this.initialTab, this.scheduleId});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  int _selectedTab = 0; // 0 = Today, 1 = Past
  bool _pastLoaded = false;
  final _scrollController = ScrollController();
  final _checklistKey = GlobalKey();
  final _taskKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // initialTab이 "past"이면 Past 탭으로 시작
    if (widget.initialTab == 'past') {
      _selectedTab = 1;
      _pastLoaded = true; // Past 데이터 로드 트리거
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(myScheduleProvider.notifier).loadSchedules(today);
      ref.read(taskProvider.notifier).loadTasks();
      // scheduleId가 있으면 해당 체크리스트 자동 열기
      if (widget.scheduleId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _openChecklist(context, widget.scheduleId!);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String section) {
    final key = section == 'task' ? _taskKey : _checklistKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  void _openChecklist(BuildContext context, String scheduleId) async {
    await context.push('/work/$scheduleId');
    // 체크리스트에서 돌아오면 목록 새로고침
    if (mounted) {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      ref.read(myScheduleProvider.notifier).loadSchedules(todayStr);
      if (_pastLoaded) {
        ref.read(myScheduleProvider.notifier).loadPastSchedules();
      }
    }
  }

  void _switchTab(int index) {
    setState(() => _selectedTab = index);
    if (index == 1 && !_pastLoaded) {
      _pastLoaded = true;
      ref.read(myScheduleProvider.notifier).loadPastSchedules();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final scheduleState = ref.watch(myScheduleProvider);
    final tasks = ref.watch(taskProvider);

    // Handle scrollTo query parameter
    final scrollTo = GoRouterState.of(context).uri.queryParameters['scrollTo'];
    if (scrollTo != null) {
      _scrollToSection(scrollTo);
    }

    final tags = <String>{};
    for (final s in scheduleState.schedules) {
      if (s.store.name.isNotEmpty) tags.add(s.store.name);
      if (s.workRoleName.isNotEmpty) tags.add(s.workRoleName);
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedTab == 0) {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await Future.wait([
            ref.read(myScheduleProvider.notifier).loadSchedules(today),
            ref.read(taskProvider.notifier).loadTasks(),
          ]);
        } else {
          await ref.read(myScheduleProvider.notifier).loadPastSchedules();
        }
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card ──
          _ProfileCard(user: user, tags: tags.toList()),
          const SizedBox(height: 16),

          // ── Checklist section ──
          Container(
            key: _checklistKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Checklist',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TabToggle(
                  selectedIndex: _selectedTab,
                  onChanged: _switchTab,
                ),
                const SizedBox(height: 12),
                if (_selectedTab == 0)
                  _TodayScheduleList(
                    scheduleState: scheduleState,
                    onOpenChecklist: _openChecklist,
                  )
                else
                  _PastContent(
                    scheduleState: scheduleState,
                    onOpenChecklist: _openChecklist,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Task section ──
          Container(
            key: _taskKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.task_alt_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Task',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TodayTaskContent(tasks: tasks),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab toggle ──────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabToggle({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTab('Today', 0),
          _buildTab('Past', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Today schedule list ─────────────────────────────────────────────────────

class _TodayScheduleList extends StatelessWidget {
  final MyScheduleState scheduleState;
  final void Function(BuildContext, String) onOpenChecklist;

  const _TodayScheduleList({
    required this.scheduleState,
    required this.onOpenChecklist,
  });

  @override
  Widget build(BuildContext context) {
    if (scheduleState.isLoading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (scheduleState.schedules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No checklists assigned today',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: scheduleState.schedules.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TodayScheduleCard(
            schedule: s,
            onTap: () => onOpenChecklist(context, s.id),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Today schedule card (with work-time coloring) ──────────────────────────

/// 날짜 비교 헬퍼: workDate가 오늘/과거/미래 중 무엇인지 반환
enum _ScheduleDateKind { today, past, future }

_ScheduleDateKind _classifyDate(DateTime workDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(workDate.year, workDate.month, workDate.day);
  if (d == today) return _ScheduleDateKind.today;
  if (d.isBefore(today)) return _ScheduleDateKind.past;
  return _ScheduleDateKind.future;
}

class _TodayScheduleCard extends StatelessWidget {
  final MySchedule schedule;
  final VoidCallback onTap;

  const _TodayScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = schedule;
    final total = a.checklistSnapshot?.totalItems ?? a.totalItems;
    final completed = a.checklistSnapshot?.completedItems ?? a.completedItems;
    final cardStatus = a.checklistStatus;
    final isDone = cardStatus == ChecklistCardStatus.done;
    final isWithinShift = a.isWithinWorkHours(DateTime.now());
    final unresolvedList = a.checklistSnapshot?.unresolvedRejections ?? [];
    final hasUnresolved = cardStatus == ChecklistCardStatus.rejected;
    final kind = _classifyDate(a.workDate);
    final isFuture = kind == _ScheduleDateKind.future;

    return GestureDetector(
      onTap: isFuture ? null : onTap,
      child: Opacity(
        opacity: isFuture ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFuture
                  ? AppColors.border
                  : cardStatus != ChecklistCardStatus.notStarted
                      ? cardStatus.color.withOpacity(0.3)
                      : isWithinShift
                          ? AppColors.accent.withOpacity(0.3)
                          : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isFuture
                      ? AppColors.bg
                      : cardStatus != ChecklistCardStatus.notStarted
                          ? cardStatus.bgColor
                          : isWithinShift
                              ? AppColors.accentBg
                              : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    DateFormat('dd').format(a.workDate),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isFuture
                          ? AppColors.textMuted
                          : cardStatus != ChecklistCardStatus.notStarted
                              ? cardStatus.color
                              : isWithinShift
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Store name + shift
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.store.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          a.workRoleName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (!isFuture && hasUnresolved) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Unresolved ${unresolvedList.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                        if (isFuture) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Upcoming',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Completion badge (오늘/과거만 표시)
              if (!isFuture && total > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardStatus != ChecklistCardStatus.notStarted
                        ? cardStatus.bgColor
                        : AppColors.accentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completed/$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cardStatus != ChecklistCardStatus.notStarted
                          ? cardStatus.color
                          : AppColors.accent,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isFuture ? AppColors.border : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User? user;
  final List<String> tags;

  const _ProfileCard({this.user, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Staff',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.roleName ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.organizationName ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/my'),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.accentBg,
                      child: Text(
                        user?.initials ?? 'ST',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '# $tag',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Today task content (with search/filter/sort) ────────────────────────────

enum _TaskSortOption { dueDate, priority, recent, name }

class _TodayTaskContent extends StatefulWidget {
  final TaskState tasks;

  const _TodayTaskContent({required this.tasks});

  @override
  State<_TodayTaskContent> createState() => _TodayTaskContentState();
}

class _TodayTaskContentState extends State<_TodayTaskContent> {
  String _searchQuery = '';
  DateTime? _selectedDate;
  _TaskSortOption _sortOption = _TaskSortOption.dueDate;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdditionalTask> get _filteredAndSorted {
    var list = widget.tasks.tasks.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        return t.title.toLowerCase().contains(q) ||
            (t.store?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Date filter
    if (_selectedDate != null) {
      list = list.where((t) {
        if (t.dueDate == null) return false;
        return t.dueDate!.year == _selectedDate!.year &&
            t.dueDate!.month == _selectedDate!.month &&
            t.dueDate!.day == _selectedDate!.day;
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case _TaskSortOption.dueDate:
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case _TaskSortOption.priority:
        const order = {'urgent': 0, 'high': 1, 'normal': 2, 'low': 3};
        list.sort((a, b) =>
            (order[a.priority] ?? 2).compareTo(order[b.priority] ?? 2));
      case _TaskSortOption.recent:
        list.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
      case _TaskSortOption.name:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final totalTasks = widget.tasks.tasks.length;
    final doneTasks =
        widget.tasks.tasks.where((t) => t.status == 'completed').length;
    final remainingTasks = totalTasks - doneTasks;
    final doneRatio = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    final filtered = _filteredAndSorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Task progress
        if (!widget.tasks.isLoading && totalTasks > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remainingTasks / $totalTasks',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                '$doneTasks done',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'done',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                'left',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: doneRatio,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Filter toolbar
        if (!widget.tasks.isLoading && totalTasks > 0) ...[
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Search bar + filter icons in one row
          Row(
            children: [
              // Search bar (expanded)
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _applySearch(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Search tasks or stores',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: _searchQuery.isNotEmpty
                                  ? _clearSearch
                                  : _applySearch,
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: _searchQuery.isNotEmpty
                                      ? AppColors.dangerBg
                                      : AppColors.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _searchQuery.isNotEmpty
                                      ? Icons.close
                                      : Icons.arrow_forward,
                                  size: 15,
                                  color: _searchQuery.isNotEmpty
                                      ? AppColors.danger
                                      : AppColors.white,
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date filter button
              _FilterIconButton(
                icon: Icons.calendar_today,
                isActive: _selectedDate != null,
                onTap: () => _pickDate(context),
              ),
              const SizedBox(width: 6),
              // Sort button
              _FilterIconButton(
                icon: Icons.swap_vert,
                isActive: _sortOption != _TaskSortOption.dueDate,
                onTap: () => _showSortOptions(context),
              ),
            ],
          ),

          // Active date chip
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Due',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                  Text(
                    DateFormat('yyyy.MM.dd').format(_selectedDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDate = null),
                    child: const Icon(Icons.close,
                        size: 14, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],

        // ── Task List
        if (widget.tasks.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (widget.tasks.tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'No tasks assigned',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No results for "$_searchQuery"'
                    : 'No tasks for selected date',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          )
        else
          ...filtered.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskCard(task: t),
            ),
          ),
      ],
    );
  }

  void _applySearch() {
    setState(() => _searchQuery = _searchController.text.trim());
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _sortTile('Due date', _TaskSortOption.dueDate),
              _sortTile('Priority', _TaskSortOption.priority),
              _sortTile('Recent', _TaskSortOption.recent),
              _sortTile('Name', _TaskSortOption.name),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String label, _TaskSortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? AppColors.accent : AppColors.text,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, size: 18, color: AppColors.accent)
          : null,
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
    );
  }
}

// ─── Task card ────────────────────────────────────────────────────────────────

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

  Color get _priorityBgColor {
    switch (task.priority) {
      case 'urgent':
        return AppColors.dangerBg;
      case 'high':
        return AppColors.warningBg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duePart = task.dueDate != null
        ? '~ ${DateFormat('MM.dd').format(task.dueDate!)}'
        : null;
    final storeName = task.store?.name ?? task.storeName;
    final subtitle = [
      if (storeName != null) storeName,
      if (duePart != null) duePart,
    ].join(' · ');

    return GestureDetector(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _priorityBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.priorityLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _priorityColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter icon button ──────────────────────────────────────────────────────

class _FilterIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentBg : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Past content (with filter chips + pagination) ───────────────────────────

class _PastContent extends StatefulWidget {
  final MyScheduleState scheduleState;
  final void Function(BuildContext, String) onOpenChecklist;

  const _PastContent({
    required this.scheduleState,
    required this.onOpenChecklist,
  });

  @override
  State<_PastContent> createState() => _PastContentState();
}

class _PastContentState extends State<_PastContent> {
  bool _showAll = false;
  bool _unresolvedOnly = false;
  DateTime? _selectedDate;
  int _currentPage = 0;
  static const _pageSize = 5;

  List<MySchedule> get _allPast => widget.scheduleState.pastSchedules;

  List<DateTime> get _workDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final a in _allPast) {
      final key = DateFormat('yyyy-MM-dd').format(a.workDate);
      if (seen.add(key)) dates.add(a.workDate);
    }
    return dates;
  }

  List<MySchedule> get _unresolvedSchedules => _allPast
      .where((a) => (a.checklistSnapshot?.unresolvedRejections ?? []).isNotEmpty)
      .toList();

  bool get _hasActiveFilter => _showAll || _unresolvedOnly || _selectedDate != null;

  List<MySchedule> get _filteredSchedules {
    var list = List<MySchedule>.from(_allPast);
    if (_showAll) return list;
    if (_unresolvedOnly) {
      list = _unresolvedSchedules;
    }
    if (_selectedDate != null) {
      list = list
          .where((a) =>
              a.workDate.year == _selectedDate!.year &&
              a.workDate.month == _selectedDate!.month &&
              a.workDate.day == _selectedDate!.day)
          .toList();
    }
    return list;
  }

  List<MySchedule> get _latestDateSchedules {
    if (_allPast.isEmpty) return [];
    final latestDate = _allPast.first.workDate;
    return _allPast
        .where((a) =>
            a.workDate.year == latestDate.year &&
            a.workDate.month == latestDate.month &&
            a.workDate.day == latestDate.day)
        .toList();
  }

  void _resetFilters() {
    setState(() {
      _showAll = false;
      _unresolvedOnly = false;
      _selectedDate = null;
      _currentPage = 0;
    });
  }

  void _toggleShowAll() {
    setState(() {
      _showAll = !_showAll;
      if (_showAll) {
        _unresolvedOnly = false;
        _selectedDate = null;
      }
      _currentPage = 0;
    });
  }

  void _toggleUnresolvedFilter() {
    setState(() {
      _unresolvedOnly = !_unresolvedOnly;
      if (_unresolvedOnly) _showAll = false;
      _currentPage = 0;
    });
  }

  void _showDateSelector() {
    final dates = _workDates;
    if (dates.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkDatePickerSheet(
        workDates: dates,
        selectedDate: _selectedDate,
        onSelect: (date) {
          Navigator.pop(ctx);
          setState(() {
            _selectedDate = date;
            _showAll = false;
            _currentPage = 0;
          });
        },
      ),
    );
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scheduleState.isPastLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allPast.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No past checklists',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow(),
        const SizedBox(height: 12),
        if (!_hasActiveFilter)
          _buildDefaultView()
        else
          _buildFilteredView(),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          isActive: _showAll,
          onTap: _toggleShowAll,
        ),
        const SizedBox(width: 6),
        if (_unresolvedSchedules.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _FilterChip(
              label: 'Unresolved ${_unresolvedSchedules.length}',
              isActive: _unresolvedOnly,
              color: AppColors.warning,
              onTap: _toggleUnresolvedFilter,
            ),
          ),
        if (_selectedDate != null)
          _FilterChip(
            label: DateFormat('MM/dd').format(_selectedDate!),
            isActive: true,
            icon: Icons.close,
            onTap: _clearDate,
          )
        else
          _FilterChip(
            label: 'Date',
            isActive: false,
            icon: Icons.calendar_today,
            onTap: _showDateSelector,
          ),
        const Spacer(),
        if (_hasActiveFilter)
          GestureDetector(
            onTap: _resetFilters,
            child: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultView() {
    final latestSchedules = _latestDateSchedules;
    final latestIds = latestSchedules.map((a) => a.id).toSet();
    final otherUnresolved =
        _unresolvedSchedules.where((a) => !latestIds.contains(a.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...latestSchedules.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PastScheduleCard(
                schedule: a,
                onTap: () => widget.onOpenChecklist(context, a.id),
              ),
            )),
        if (otherUnresolved.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'Previous unresolved: ${otherUnresolved.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...otherUnresolved.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PastScheduleCard(
                  schedule: a,
                  onTap: () => widget.onOpenChecklist(context, a.id),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildFilteredView() {
    final filtered = _filteredSchedules;

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No matching records',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final totalPages = (filtered.length / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pageItems.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PastScheduleCard(
                schedule: a,
                onTap: () => widget.onOpenChecklist(context, a.id),
              ),
            )),
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          _buildPagination(totalPages),
        ],
      ],
    );
  }

  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _currentPage > 0 ? AppColors.bg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 18,
              color: _currentPage > 0 ? AppColors.text : AppColors.border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_currentPage + 1} / $totalPages',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _currentPage < totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _currentPage < totalPages - 1
                  ? AppColors.bg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: _currentPage < totalPages - 1
                  ? AppColors.text
                  : AppColors.border,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Past schedule card ──────────────────────────────────────────────────────

class _PastScheduleCard extends StatelessWidget {
  final MySchedule schedule;
  final VoidCallback onTap;

  const _PastScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = schedule;
    final total = a.checklistSnapshot?.totalItems ?? a.totalItems;
    final completed = a.checklistSnapshot?.completedItems ?? a.completedItems;
    final cardStatus = a.checklistStatus;
    final unresolvedList = a.checklistSnapshot?.unresolvedRejections ?? [];
    final hasUnresolved = cardStatus == ChecklistCardStatus.rejected;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[a.workDate.weekday - 1];
    final dateStr = '${DateFormat('MM/dd').format(a.workDate)} ($wd)';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardStatus == ChecklistCardStatus.rejected
                ? AppColors.danger.withOpacity(0.4)
                : cardStatus == ChecklistCardStatus.done
                    ? AppColors.success.withOpacity(0.4)
                    : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Date badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardStatus.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('dd').format(a.workDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cardStatus.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (cardStatus != ChecklistCardStatus.notStarted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: cardStatus.bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cardStatus.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cardStatus.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Completion badge
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardStatus.bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completed/$total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cardStatus.color,
                      ),
                    ),
                  ),
              ],
            ),
            // Unresolved rejection feedback
            if (hasUnresolved) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: unresolvedList.map((item) {
                    return Padding(
                      padding: EdgeInsets.only(
                          top: item == unresolvedList.first ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.feedback_outlined,
                                size: 14, color: AppColors.warning),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (item.rejectionComment != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.rejectionComment!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isActive ? activeColor : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Work date picker bottom sheet ───────────────────────────────────────────

class _WorkDatePickerSheet extends StatefulWidget {
  final List<DateTime> workDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;

  const _WorkDatePickerSheet({
    required this.workDates,
    this.selectedDate,
    required this.onSelect,
  });

  @override
  State<_WorkDatePickerSheet> createState() => _WorkDatePickerSheetState();
}

class _WorkDatePickerSheetState extends State<_WorkDatePickerSheet> {
  late DateTime _currentMonth;
  late Set<String> _workDateKeys;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.workDates.isNotEmpty
        ? DateTime(widget.workDates.first.year, widget.workDates.first.month)
        : DateTime(DateTime.now().year, DateTime.now().month);
    _workDateKeys = widget.workDates
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toSet();
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _currentMonth = next);
    }
  }

  bool _isWorkDate(DateTime day) {
    return _workDateKeys.contains(DateFormat('yyyy-MM-dd').format(day));
  }

  bool _isSelected(DateTime day) {
    if (widget.selectedDate == null) return false;
    return day.year == widget.selectedDate!.year &&
        day.month == widget.selectedDate!.month &&
        day.day == widget.selectedDate!.day;
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Work Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _prevMonth,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_left, size: 22, color: AppColors.textSecondary),
                ),
              ),
              Text(
                DateFormat('yyyy MMM').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              GestureDetector(
                onTap: _nextMonth,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_right, size: 22, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Weekday headers
          Row(
            children: weekdayLabels.map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          ..._buildWeeks(year, month, daysInMonth, firstWeekday),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Work day',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'No work',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeks(int year, int month, int daysInMonth, int firstWeekday) {
    final weeks = <Widget>[];
    final offset = firstWeekday - 1;
    var day = 1;

    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if ((weeks.isEmpty && i < offset) || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 40)));
        } else {
          final thisDay = DateTime(year, month, day);
          final isWork = _isWorkDate(thisDay);
          final isSel = _isSelected(thisDay);

          cells.add(Expanded(
            child: GestureDetector(
              onTap: isWork ? () => widget.onSelect(thisDay) : null,
              child: Container(
                height: 40,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.accent
                      : isWork
                          ? AppColors.accentBg
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isWork ? FontWeight.w700 : FontWeight.w400,
                      color: isSel
                          ? AppColors.white
                          : isWork
                              ? AppColors.accent
                              : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ));
          day++;
        }
      }
      weeks.add(Row(children: cells));
    }
    return weeks;
  }
}

// ─── Checklist bottom sheet ───────────────────────────────────────────────────

class _ChecklistBottomSheet extends ConsumerStatefulWidget {
  final String scheduleId;

  const _ChecklistBottomSheet({required this.scheduleId});

  @override
  ConsumerState<_ChecklistBottomSheet> createState() =>
      _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState
    extends ConsumerState<_ChecklistBottomSheet> {
  bool _celebrationShown = false;
  bool _isUploading = false;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(myScheduleProvider.notifier)
          .loadSchedule(widget.scheduleId),
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _onItemTap(ChecklistItem item) async {
    if (_isUploading) return;

    // Rejected → 채팅 화면에서 재제출
    if (item.isRejected && !item.isResolved) {
      _showItemDetailSheet(item);
      return;
    }

    // Already completed → 채팅 화면
    if (item.isCompleted) {
      _showItemDetailSheet(item);
      return;
    }

    // Requires verification → open verification sheet
    if (item.requiresVerification) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VerificationBottomSheet(
          scheduleId: widget.scheduleId,
          item: item,
        ),
      );
    } else {
      ref.read(myScheduleProvider.notifier).toggleChecklistItem(
            widget.scheduleId,
            item.index,
            true,
          );
    }
  }

  Future<void> _handleRespondToRejection(ChecklistItem item) async {
    String? photoUrl;
    String? responseComment;

    if (item.requiresPhoto) {
      photoUrl = await _handlePhotoCapture();
      if (photoUrl == null) return;
    }

    responseComment = await _showNoteDialog(
      title: 'Response',
      hint: 'Enter your response to the rejection...',
    );
    if (responseComment == null) return;

    ref.read(myScheduleProvider.notifier).respondToRejection(
          widget.scheduleId,
          item.index,
          responseComment: responseComment,
          photoUrls: photoUrl != null ? [photoUrl] : null,
        );
  }

  Future<String?> _handlePhotoCapture() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return null;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return null;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final filename =
          'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const contentType = 'image/jpeg';
      final storage = ref.read(storageServiceProvider);
      final urls = await storage.getPresignedUrl(filename, contentType);
      await storage.uploadFile(urls['upload_url']!, bytes, contentType);
      return urls['file_url'];
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Photo upload failed');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<ImageSource?> _showPhotoSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog({
    String title = 'Add Note',
    String hint = 'Enter verification note...',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showItemDetailSheet(ChecklistItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistChatScreen(
          scheduleId: widget.scheduleId,
          item: item,
        ),
      ),
    ).then((_) {
      // 채팅 화면에서 돌아오면 데이터 새로고침
      ref.read(myScheduleProvider.notifier).loadSchedule(widget.scheduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myScheduleProvider);
    final schedule = state.selected;

    final isAllDoneCheck = schedule != null &&
        (schedule.checklistSnapshot?.isAllCompleted == true ||
            (schedule.totalItems > 0 &&
                schedule.completedItems == schedule.totalItems));
    if (isAllDoneCheck && !_celebrationShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _celebrationShown = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All checklist items complete! Great job!'),
              duration: Duration(seconds: 2),
            ),
          );
          _startAutoCloseTimer();
        }
      });
    }

    final snapshot = schedule?.checklistSnapshot;
    final total = snapshot?.totalItems ?? schedule?.totalItems ?? 0;
    final completed = snapshot?.completedItems ?? schedule?.completedItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isAllDone = total > 0 && completed == total;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '$completed / $total',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),

              // Progress bar
              if (total > 0) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
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
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),

              // Checklist items
              Expanded(
                child: state.isLoading && schedule == null
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot == null || snapshot.items.isEmpty
                        ? const Center(
                            child: Text(
                              'No checklist items',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: snapshot.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = snapshot.items[index];
                              return _ChecklistItemTile(
                                item: item,
                                onToggle: () => _onItemTap(item),
                                onTapDetail: () =>
                                    _showItemDetailSheet(item),
                              );
                            },
                          ),
              ),

              // Close / Done button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: isAllDone
                        ? ElevatedButton(
                            onPressed: () {
                              _autoCloseTimer?.cancel();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'DONE',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Checklist item tile with rejection support ──────────────────────────────

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onTapDetail;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onTapDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.isRejected
                      ? AppColors.warningBg
                      : item.isApproved
                          ? AppColors.success
                          : item.isCompleted
                              ? AppColors.success
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isRejected
                        ? AppColors.warning
                        : item.isApproved
                            ? AppColors.success
                            : item.isCompleted
                                ? AppColors.success
                                : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.isRejected
                    ? const Icon(Icons.refresh,
                        size: 14, color: AppColors.warning)
                    : item.isApproved
                        ? const Icon(Icons.check_circle,
                            size: 16, color: Colors.white)
                        : item.isCompleted
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.isCompleted && !item.isRejected
                                ? AppColors.textMuted
                                : AppColors.text,
                            decoration: item.isCompleted && !item.isRejected
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      if (item.isApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Approved',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        )
                      else if (item.isRejected && !item.isResolved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Action Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (item.isCompleted &&
                      !item.isRejected &&
                      item.completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${item.completedAtDisplay}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                  // Inline approval feedback
                  if (item.isApproved &&
                      (item.approvalComment != null ||
                          item.approvalPhotoUrls.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTapDetail,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 12, color: AppColors.success),
                                const SizedBox(width: 4),
                                if (item.approvedBy != null)
                                  Text(
                                    item.approvedBy!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                            if (item.approvalComment != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.approvalComment!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.text,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Inline rejection feedback
                  if (item.isRejected &&
                      (item.rejectionComment != null ||
                          item.rejectionPhotoUrls.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTapDetail,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 12, color: AppColors.warning),
                                const SizedBox(width: 4),
                                if (item.rejectedBy != null)
                                  Text(
                                    item.rejectedBy!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                const Spacer(),
                                if (item.rejectedAtDisplay != null)
                                  Text(
                                    item.rejectedAtDisplay!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.rejectionComment != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.rejectionComment!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.text,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (item.rejectionPhotoUrls.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 48,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: item.rejectionPhotoUrls.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 4),
                                  itemBuilder: (context, i) => ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.rejectionPhotoUrls[i],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: AppColors.border,
                                        child: const Icon(Icons.broken_image,
                                            size: 16,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Verification type icons
            if (item.requiresVerification &&
                !item.isCompleted &&
                !item.isRejected) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.camera_alt_outlined,
                          size: 16,
                          color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  if (item.requiresComment)
                    Icon(Icons.edit_note,
                        size: 18,
                        color: AppColors.accent.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Verification bottom sheet ──────────────────────────────────────────────

class _VerificationBottomSheet extends ConsumerStatefulWidget {
  final String scheduleId;
  final ChecklistItem item;

  const _VerificationBottomSheet({
    required this.scheduleId,
    required this.item,
  });

  @override
  ConsumerState<_VerificationBottomSheet> createState() =>
      _VerificationBottomSheetState();
}

class _VerificationBottomSheetState
    extends ConsumerState<_VerificationBottomSheet> {
  final _noteController = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting || _isUploading) return false;
    if (widget.item.requiresPhoto && _uploadedFileUrl == null) return false;
    if (widget.item.requiresComment && _noteController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _uploadToTemp(Uint8List bytes) async {
    setState(() => _isUploading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final filename = 'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const contentType = 'image/jpeg';
      final urls = await storage.getPresignedUrl(filename, contentType);
      await storage.uploadFile(urls['upload_url']!, bytes, contentType);
      if (mounted) {
        setState(() {
          _pickedImageBytes = bytes;
          _uploadedFileUrl = urls['file_url'];
        });
      }
    } catch (e) {
      debugPrint('[Verification] Photo upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      await _uploadToTemp(bytes);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      await _uploadToTemp(bytes);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    await ref.read(myScheduleProvider.notifier).toggleChecklistItem(
      widget.scheduleId,
      widget.item.index,
      true,
      photoUrls: _uploadedFileUrl != null ? [_uploadedFileUrl!] : null,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Verification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Task info
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (widget.item.description != null &&
                        widget.item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.item.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Photo verification section
                    if (widget.item.requiresPhoto) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Photo',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please upload verification photo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Image preview or placeholder
                            if (_pickedImageBytes != null)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _pickedImageBytes!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (_isUploading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(color: AppColors.white),
                                        ),
                                      ),
                                    ),
                                  if (!_isUploading) Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _pickedImageBytes = null;
                                        _uploadedFileUrl = null;
                                      }),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Add a photo',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Camera / Gallery buttons
                            if (_pickedImageBytes == null)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _takePhoto,
                                      icon: const Icon(Icons.camera_alt, size: 16),
                                      label: const Text('Camera'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.accent),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.photo_library, size: 16),
                                      label: const Text('Gallery'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Note section
                    if (widget.item.requiresComment) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Note',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please describe the work done.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteController,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your note...',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                                filled: true,
                                fillColor: AppColors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.accent),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              // DONE button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'DONE',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Item detail bottom sheet with timeline ──────────────────────────────────

class _ItemDetailSheet extends StatelessWidget {
  final ChecklistItem item;

  const _ItemDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final events = item.fullHistory;
    final hasPending = item.isRejected && !item.isResolved;
    final totalSteps = events.length + (hasPending ? 1 : 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Status header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildCurrentStatusBadge(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedByName ?? item.completedBy ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedAtDisplay ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Timeline
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  itemCount: totalSteps,
                  itemBuilder: (context, index) {
                    if (hasPending && index == events.length) {
                      return const _TimelineStepCard(
                        type: 'pending',
                        comment: 'Awaiting resubmission',
                        isLast: true,
                      );
                    }
                    final event = events[index];
                    return _TimelineStepCard(
                      type: event.type,
                      by: event.by,
                      at: event.atDisplay,
                      comment: event.comment,
                      photoUrls: event.photoUrls,
                      isLast: index == totalSteps - 1,
                    );
                  },
                ),
              ),

              // Close button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStatusBadge() {
    final String label;
    final Color color;
    final Color bg;
    final IconData icon;

    if (item.isApproved) {
      label = 'Approved';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle;
    } else if (item.isRejected && !item.isResolved) {
      label = 'Revision Requested';
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFFFFBEB);
      icon = Icons.edit_note;
    } else if (item.isResolved) {
      label = 'Resubmitted';
      color = const Color(0xFF6C5CE7);
      bg = const Color(0xFFF0EEFF);
      icon = Icons.replay;
    } else if (item.isCompleted) {
      label = 'Submitted';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle;
    } else {
      label = 'Not Submitted';
      color = const Color(0xFF9CA3AF);
      bg = const Color(0xFFF9FAFB);
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline step card ─────────────────────────────────────────────────────

class _TimelineStepCard extends StatelessWidget {
  final String type;
  final String? by;
  final String? at;
  final String? comment;
  final List<String> photoUrls;
  final bool isLast;

  const _TimelineStepCard({
    required this.type,
    this.by,
    this.at,
    this.comment,
    this.photoUrls = const [],
    this.isLast = false,
  });

  static const _submitColor = Color(0xFF3B82F6);
  static const _submitBg = Color(0xFFEFF6FF);
  static const _changeReqColor = Color(0xFFF59E0B);
  static const _changeReqBg = Color(0xFFFFFBEB);
  static const _resubmitColor = Color(0xFF6C5CE7);
  static const _resubmitBg = Color(0xFFF0EEFF);
  static const _approvedColor = Color(0xFF10B981);
  static const _approvedBg = Color(0xFFD1FAE5);
  static const _pendingColor = Color(0xFF9CA3AF);
  static const _pendingBg = Color(0xFFF9FAFB);

  Color get _dotColor {
    switch (type) {
      case 'submitted':
        return _submitColor;
      case 'resubmitted':
        return _resubmitColor;
      case 'rejected':
        return _changeReqColor;
      case 'approved':
        return _approvedColor;
      case 'pending_re_review':
        return _changeReqColor;
      case 'message':
      case 'message_photo':
        return _submitColor;
      case 'pending':
        return _pendingColor;
      default:
        return _pendingColor;
    }
  }

  Color get _cardBg {
    switch (type) {
      case 'submitted':
        return _submitBg;
      case 'resubmitted':
        return _resubmitBg;
      case 'rejected':
        return _changeReqBg;
      case 'approved':
        return _approvedBg;
      case 'pending_re_review':
        return _changeReqBg;
      case 'message':
      case 'message_photo':
        return _submitBg;
      case 'pending':
        return _pendingBg;
      default:
        return _pendingBg;
    }
  }

  String get _label {
    switch (type) {
      case 'submitted':
        return 'Submitted';
      case 'resubmitted':
        return 'Resubmitted';
      case 'rejected':
        return 'Revision Requested';
      case 'approved':
        return 'Approved';
      case 'pending_re_review':
        return 'Pending Re-review';
      case 'message':
        return 'Message';
      case 'message_photo':
        return 'Photo';
      case 'pending':
        return 'Pending';
      default:
        return type;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'submitted':
        return Icons.upload_file;
      case 'resubmitted':
        return Icons.replay;
      case 'rejected':
        return Icons.edit_note;
      case 'approved':
        return Icons.check_circle;
      case 'pending_re_review':
        return Icons.hourglass_top;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'message_photo':
        return Icons.image_outlined;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dotColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _dotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon, size: 12, color: _dotColor),
                            const SizedBox(width: 4),
                            Text(
                              _label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _dotColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (at != null)
                        Text(
                          at!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  if (by != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          by ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (comment != null && comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        comment!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhotoCarousel(photoUrls: photoUrls),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo carousel ─────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;

  const _PhotoCarousel({required this.photoUrls});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.length == 1) {
      return _buildSinglePhoto(context, widget.photoUrls[0]);
    }
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            itemCount: widget.photoUrls.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildPhoto(context, widget.photoUrls[index], index),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photoUrls.length,
            (i) => Container(
              width: i == _currentPage ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color:
                    i == _currentPage ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context, String url, int index) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  void _openFullScreen(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(
          photoUrls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _photoErrorWidget() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 28, color: AppColors.textMuted),
          SizedBox(height: 4),
          Text('Failed to load image',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _photoLoadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      width: double.infinity,
      height: 160,
      color: AppColors.bg,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Full screen photo viewer ───────────────────────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenPhotoViewer({
    required this.photoUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoUrls.length;
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.photoUrls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('Failed to load image',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white54)),
                        ],
                      ),
                      loadingBuilder: (_, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (total > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
