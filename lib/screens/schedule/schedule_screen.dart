/// Schedule main screen — READ ONLY mode (MVP)
///
/// Weekly list view (default) or monthly calendar.
/// Weekly: summary card + scrollable week rows with shift cards.
/// Monthly: existing calendar grid.
/// Tap date → bottom sheet detail.
///
/// Schedule request (신청 / 복사 / 편집 / 삭제) 기능은 현재 비활성화됨.
/// 필요 시 admin의 Schedule Settings → Approval Workflow →
/// "Allow staff to request schedules from app" 를 켜면 재활성화 계획.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ────── Unified shift item for combining entries + requests ──────

class _ShiftItem {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String storeName;
  final String workRoleName;
  final String status; // confirmed, submitted, modified, rejected
  final int netMinutes;
  final String? requestId; // non-null for editable requests
  final String? entryId;
  final ScheduleEntry? entry;
  final ScheduleRequest? request;

  const _ShiftItem({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.storeName,
    required this.workRoleName,
    required this.status,
    required this.netMinutes,
    this.requestId,
    this.entryId,
    this.entry,
    this.request,
  });
}

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(scheduleProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final isWeekly = state.viewMode == ScheduleViewMode.weekly;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // View toggle
          _ViewToggle(
            mode: state.viewMode,
            onChanged: (m) =>
                ref.read(scheduleProvider.notifier).setViewMode(m),
          ),
          // Navigation
          if (isWeekly)
            _WeekNav(
              weekStart: state.currentWeekStart,
              onPrev: () => ref.read(scheduleProvider.notifier).previousWeek(),
              onNext: () => ref.read(scheduleProvider.notifier).nextWeek(),
              onToday: () => ref.read(scheduleProvider.notifier).goToToday(),
            )
          else
            _MonthNav(
              month: state.currentMonth,
              onPrev: () =>
                  ref.read(scheduleProvider.notifier).previousMonth(),
              onNext: () => ref.read(scheduleProvider.notifier).nextMonth(),
              onToday: () => ref.read(scheduleProvider.notifier).goToToday(),
            ),
          // Content
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : isWeekly
                    ? _weeklyContent(state)
                    : _monthlyContent(state),
          ),
        ],
      ),
    );
  }

  // ── Build unified shift list from entries + requests ──

  List<_ShiftItem> _buildShiftItems(
      List<ScheduleEntry> entries, List<ScheduleRequest> requests) {
    final items = <_ShiftItem>[];

    // 엔트리 ID 세트 (request_id 기반 중복 방지)
    final entryRequestIds = <String>{};
    for (final e in entries) {
      if (e.requestId != null) entryRequestIds.add(e.requestId!);
      items.add(_ShiftItem(
        date: e.workDate,
        startTime: e.startTime,
        endTime: e.endTime,
        storeName: e.storeName ?? '',
        workRoleName: e.workRoleName ?? '',
        status: 'confirmed',
        netMinutes: e.netWorkMinutes,
        entryId: e.id,
        entry: e,
      ));
    }

    for (final r in requests) {
      // accepted 이미 entry로 표시됨
      if (r.status == 'accepted') continue;
      // submitted인데 매칭 entry 있으면 skip
      if (r.status == 'submitted') {
        final hasEntry = entries.any((e) =>
            _fmt(e.workDate) == _fmt(r.workDate) &&
            (e.storeName ?? '') == (r.storeName ?? '') &&
            e.startTime == (r.preferredStartTime ?? '') &&
            e.endTime == (r.preferredEndTime ?? ''));
        if (hasEntry) continue;
      }
      final minutes = _estimateMinutes(r);
      items.add(_ShiftItem(
        date: r.workDate,
        startTime: r.preferredStartTime ?? '',
        endTime: r.preferredEndTime ?? '',
        storeName: r.storeName ?? '',
        workRoleName: r.workRoleName ?? '',
        status: r.status,
        netMinutes: minutes,
        requestId: r.id,
        request: r,
      ));
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  // ── Weekly content: summary + week rows ──

  Widget _weeklyContent(ScheduleState state) {
    final allShifts = _buildShiftItems(state.entries, state.requests);

    // 현재 주의 shifts (summary용)
    final weekEnd = state.currentWeekStart.add(const Duration(days: 6));
    final currentWeekShifts = allShifts.where((s) =>
        !s.date.isBefore(state.currentWeekStart) &&
        !s.date.isAfter(weekEnd)).toList();

    // 현재 월의 모든 주 (일요일 시작) 계산
    final weeks = _weeksInMonth(state.currentMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          _WeeklySummaryCard(shifts: currentWeekShifts),
          const SizedBox(height: 8),
          ...weeks.map((weekStart) {
            final wEnd = weekStart.add(const Duration(days: 6));
            final weekShifts = allShifts.where((s) =>
                !s.date.isBefore(weekStart) &&
                !s.date.isAfter(wEnd)).toList();

            return _WeekRow(
              weekStart: weekStart,
              shifts: weekShifts,
              onShiftTap: (item) => _showDayDetail(context, item.date, state),
            );
          }),
        ],
      ),
    );
  }

  List<DateTime> _weeksInMonth(DateTime month) {
    // 월의 첫째날이 속한 주의 일요일 ~ 마지막날이 속한 주의 일요일
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstSunday =
        firstDay.subtract(Duration(days: firstDay.weekday % 7));
    final lastSunday =
        lastDay.subtract(Duration(days: lastDay.weekday % 7));

    final weeks = <DateTime>[];
    var d = firstSunday;
    while (!d.isAfter(lastSunday)) {
      weeks.add(d);
      d = d.add(const Duration(days: 7));
    }
    return weeks;
  }

  // Copy/Paste/Request/Delete 메서드 제거됨 (read-only mode)
  // admin 설정 `schedule.allow_staff_request` 가 켜지면 다시 복원 예정.

  // ── Monthly content (keep as-is) ──

  Widget _monthlyContent(ScheduleState state) {
    return Column(
      children: [
        _WeekdayHeader(),
        Expanded(
          child: _MonthCalendar(
            month: state.currentMonth,
            entries: state.entries,
            requests: state.requests,
            onDayTap: (date) => _showDayDetail(context, date, state),
          ),
        ),
      ],
    );
  }

  void _showDayDetail(
      BuildContext context, DateTime date, ScheduleState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(
        initialDate: date,
        allEntries: state.entries,
        allRequests: state.requests,
      ),
    );
  }
}

// ────── View Toggle (Weekly / Monthly) ──────

class _ViewToggle extends StatelessWidget {
  final ScheduleViewMode mode;
  final ValueChanged<ScheduleViewMode> onChanged;

  const _ViewToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _segBtn('Weekly', mode == ScheduleViewMode.weekly,
                () => onChanged(ScheduleViewMode.weekly)),
            _segBtn('Monthly', mode == ScheduleViewMode.monthly,
                () => onChanged(ScheduleViewMode.monthly)),
          ],
        ),
      ),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ────── Week Navigation ──────

class _WeekNav extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _WeekNav({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    final label = '${_monthAbbr[weekStart.month - 1]} ${weekStart.day}'
        ' – ${_monthAbbr[end.month - 1]} ${end.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPrev,
            child: const Icon(Icons.chevron_left,
                size: 18, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          GestureDetector(
            onTap: onNext,
            child: const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────── Weekly Summary Card ──────

class _WeeklySummaryCard extends StatelessWidget {
  final List<_ShiftItem> shifts;

  const _WeeklySummaryCard({required this.shifts});

  @override
  Widget build(BuildContext context) {
    int totalMinutes = 0;
    int pending = 0, confirmed = 0, rejected = 0;
    final workDates = <String>{};

    for (final s in shifts) {
      if (s.status == 'rejected') {
        rejected++;
        continue;
      }
      totalMinutes += s.netMinutes;
      workDates.add(_fmt(s.date));
      if (s.status == 'confirmed') {
        confirmed++;
      } else {
        // submitted, modified
        pending++;
      }
    }

    final totalHours = totalMinutes ~/ 60;
    final dayCount = workDates.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This week',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dayCount days · ${totalHours}h',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (pending > 0)
                  _badge('Pending $pending', AppColors.accent, AppColors.accentBg),
                if (confirmed > 0)
                  _badge('Confirmed $confirmed', AppColors.success, AppColors.successBg),
                if (rejected > 0)
                  _badge('Rejected $rejected', AppColors.danger, AppColors.dangerBg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ────── Week Row Card ──────

class _WeekRow extends StatelessWidget {
  final DateTime weekStart;
  final List<_ShiftItem> shifts;
  final void Function(_ShiftItem) onShiftTap;

  const _WeekRow({
    required this.weekStart,
    required this.shifts,
    required this.onShiftTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = '${_monthAbbr[weekStart.month - 1]} ${weekStart.day}'
        ' – ${_monthAbbr[weekEnd.month - 1]} ${weekEnd.day}';

    final totalMinutes =
        shifts.where((s) => s.status != 'rejected').fold<int>(0, (sum, s) => sum + s.netMinutes);
    final totalHours = totalMinutes ~/ 60;
    final shiftCount = shifts.length;
    final subLabel = shiftCount > 0
        ? '$shiftCount shifts · ${totalHours}h'
        : 'No shifts';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (action buttons 제거됨 — read-only)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rangeLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: shiftCount > 0
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Shift cards
            if (shifts.isNotEmpty) ...[
              const Divider(height: 1, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: shifts
                      .map((s) => _ShiftCard(
                            shift: s,
                            onTap: () => onShiftTap(s),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────── Shift Card ──────

class _ShiftCard extends StatelessWidget {
  final _ShiftItem shift;
  final VoidCallback onTap;

  const _ShiftCard({
    required this.shift,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg) = _statusColors(shift.status);
    final isPending = shift.status == 'submitted' || shift.status == 'modified';
    final isRejected = shift.status == 'rejected';

    final dow = shift.date.weekday % 7; // 0=Sun
    final dateLabel =
        '${_monthAbbr[shift.date.month - 1]} ${shift.date.day} ${_weekdays[dow]}';
    final timeLabel = '${_trimTime(shift.startTime)} – ${_trimTime(shift.endTime)}';
    final hours = shift.netMinutes ~/ 60;
    final mins = shift.netMinutes % 60;
    final hoursLabel = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';

    // Border style: dashed-like for pending (double border), solid for others
    final borderColor = isPending
        ? statusColor.withValues(alpha: 0.5)
        : isRejected
            ? statusColor.withValues(alpha: 0.3)
            : statusBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isPending ? 1.5 : 1,
            // Flutter doesn't support dashed borders natively;
            // use thicker border for pending to visually differentiate
          ),
        ),
        child: Row(
          children: [
            // Left: status indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            // Middle: info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isRejected
                              ? AppColors.textMuted
                              : AppColors.text,
                          decoration: isRejected
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hoursLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isRejected
                          ? AppColors.textMuted
                          : AppColors.textSecondary,
                      decoration:
                          isRejected ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${shift.storeName} · ${shift.workRoleName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Edit/Delete 버튼 제거됨 — read-only mode
          ],
        ),
      ),
    );
  }
}

// ────── Month Navigation ──────

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPrev,
            child: const Icon(Icons.chevron_left,
                size: 24, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNext,
            child: const Icon(Icons.chevron_right,
                size: 24, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Request button 제거됨 — read-only mode
        ],
      ),
    );
  }
}

// ────── Weekday Header ──────

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: List.generate(7, (i) {
          Color color = AppColors.textMuted;
          if (i == 0) color = AppColors.danger;
          if (i == 6) color = AppColors.accent;
          return Expanded(
            child: Center(
              child: Text(
                _weekdays[i],
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ────── Month Calendar Grid ──────

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final List<ScheduleEntry> entries;
  final List<ScheduleRequest> requests;
  final void Function(DateTime) onDayTap;

  const _MonthCalendar({
    required this.month,
    required this.entries,
    required this.requests,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(month);
    final rows = days.length ~/ 7;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: List.generate(rows, (rowIdx) {
          return Expanded(
            child: Row(
              children: List.generate(7, (colIdx) {
                final day = days[rowIdx * 7 + colIdx];
                return Expanded(
                  child: _DayCell(
                    date: day,
                    isCurrentMonth: day.month == month.month,
                    entries: entries,
                    requests: requests,
                    onTap: () => onDayTap(day),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  List<DateTime> _calendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7;
    final start = firstDay.subtract(Duration(days: startOffset));
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final endOffset = 6 - (lastDay.weekday % 7);
    final end = lastDay.add(Duration(days: endOffset));
    final days = <DateTime>[];
    var d = start;
    while (!d.isAfter(end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }
}

// ────── Day Cell ──────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final List<ScheduleEntry> entries;
  final List<ScheduleRequest> requests;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.entries,
    required this.requests,
    required this.onTap,
  });

  List<_EntryGroup> _groupEntries(Iterable<ScheduleEntry> dayEntries) {
    final map = <String, _EntryGroup>{};
    for (final e in dayEntries) {
      final key = '${e.storeName ?? ''}-${e.workRoleName ?? ''}';
      if (!map.containsKey(key)) {
        map[key] = _EntryGroup(
          storeName: e.storeName ?? '',
          workRoleName: e.workRoleName ?? '',
          timeBlocks: [],
        );
      }
      map[key]!.timeBlocks.add((start: e.startTime, end: e.endTime));
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmt(date);
    final dayEntries = entries.where((e) => _fmt(e.workDate) == dateStr).toList();
    // Filter out accepted requests (already shown as entries)
    final dayRequests = requests.where((r) {
      if (_fmt(r.workDate) != dateStr) return false;
      if (r.status == 'accepted') return false;
      // skip submitted if matching entry exists
      if (r.status == 'submitted') {
        return !dayEntries.any((e) =>
            (e.storeName ?? '') == (r.storeName ?? '') &&
            e.startTime == (r.preferredStartTime ?? '') &&
            e.endTime == (r.preferredEndTime ?? ''));
      }
      return true;
    });
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final dow = date.weekday % 7;
    final hasModified = dayRequests.any((r) => r.status == 'modified');
    final grouped = _groupEntries(dayEntries);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 3, left: 1, right: 1, bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: Opacity(
          opacity: isCurrentMonth ? 1.0 : 0.25,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: AppColors.accent, shape: BoxShape.circle)
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppColors.white
                            : dow == 0
                                ? AppColors.danger
                                : dow == 6
                                    ? AppColors.accent
                                    : AppColors.text,
                      ),
                    ),
                  ),
                  if (hasModified)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Expanded(
                child: ClipRect(
                  child: Column(
                    children: [
                      ...grouped.take(2).map((g) => _previewGroupWidget(
                            g.storeName,
                            g.workRoleName,
                            g.timeBlocks,
                            'confirmed',
                          )),
                      ...dayRequests
                          .take(grouped.isEmpty ? 2 : 1)
                          .map((r) {
                        final isModified = r.status == 'modified';
                        final displayStatus =
                            isModified ? 'confirmed' : r.status;
                        final start = r.preferredStartTime ?? '';
                        final end = r.preferredEndTime ?? '';
                        return _previewGroupWidget(
                          r.storeName ?? '',
                          r.workRoleName ?? '',
                          [(start: start, end: end)],
                          displayStatus,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewGroupWidget(String store, String role,
      List<({String start, String end})> timeBlocks, String status) {
    final (color, bg) = _statusColors(status);
    final isRejected = status == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      width: double.infinity,
      child: Column(
        children: [
          Text(store,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2)),
          Text(role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.2)),
          ...timeBlocks.map((tb) => Text(
                '${_trimTime(tb.start)}~${_trimTime(tb.end)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.3,
                    decoration:
                        isRejected ? TextDecoration.lineThrough : null),
              )),
        ],
      ),
    );
  }
}

class _EntryGroup {
  final String storeName;
  final String workRoleName;
  final List<({String start, String end})> timeBlocks;

  _EntryGroup({
    required this.storeName,
    required this.workRoleName,
    required this.timeBlocks,
  });
}

// ────── Day Detail Bottom Sheet ──────

class _DayDetailSheet extends StatefulWidget {
  final DateTime initialDate;
  final List<ScheduleEntry> allEntries;
  final List<ScheduleRequest> allRequests;

  const _DayDetailSheet({
    required this.initialDate,
    required this.allEntries,
    required this.allRequests,
  });

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  late DateTime _date;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  void _prevDay() =>
      setState(() => _date = _date.subtract(const Duration(days: 1)));
  void _nextDay() =>
      setState(() => _date = _date.add(const Duration(days: 1)));

  List<_EntryGroup> _groupEntries(List<ScheduleEntry> entries) {
    final map = <String, _EntryGroup>{};
    for (final e in entries) {
      final key = '${e.storeName ?? ''}-${e.workRoleName ?? ''}';
      map.putIfAbsent(
          key,
          () => _EntryGroup(
                storeName: e.storeName ?? '',
                workRoleName: e.workRoleName ?? '',
                timeBlocks: [],
              ));
      map[key]!.timeBlocks.add((start: e.startTime, end: e.endTime));
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmt(_date);
    final dayEntries =
        widget.allEntries.where((e) => _fmt(e.workDate) == dateStr).toList();
    // Filter out accepted requests (shown as entries) and submitted duplicates
    final dayRequests = widget.allRequests.where((r) {
      if (_fmt(r.workDate) != dateStr) return false;
      if (r.status == 'accepted') return false;
      if (r.status == 'submitted') {
        return !dayEntries.any((e) =>
            (e.storeName ?? '') == (r.storeName ?? '') &&
            e.startTime == (r.preferredStartTime ?? '') &&
            e.endTime == (r.preferredEndTime ?? ''));
      }
      return true;
    }).toList();
    final grouped = _groupEntries(dayEntries);
    final hasContent = grouped.isNotEmpty || dayRequests.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _prevDay,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left,
                        size: 24, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_dayNames[_date.weekday - 1]}, ${_monthAbbr[_date.month - 1]} ${_date.day}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                GestureDetector(
                  onTap: _nextDay,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right,
                        size: 24, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 22, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: hasContent
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...grouped
                            .map((g) => _confirmedSection(context, g, dayEntries)),
                        if (grouped.isNotEmpty && dayRequests.isNotEmpty)
                          const SizedBox(height: 16),
                        ...dayRequests.map((r) => _requestSection(r)),
                      ],
                    ),
                  )
                : _emptyState(),
          ),
        ],
      ),
    );
  }

  Widget _confirmedSection(
      BuildContext context, _EntryGroup group, List<ScheduleEntry> dayEntries) {
    final groupEntries = dayEntries
        .where((e) =>
            (e.storeName ?? '') == group.storeName &&
            (e.workRoleName ?? '') == group.workRoleName)
        .toList();
    final totalMinutes =
        groupEntries.fold<int>(0, (sum, e) => sum + e.netWorkMinutes);
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final totalDisplay = m > 0 ? '${h}h ${m}m' : '${h}h';

    // 첫 번째 entry의 ID를 사용해 checklist 화면으로 이동
    final firstEntry = groupEntries.isNotEmpty ? groupEntries.first : null;
    final hasChecklist = firstEntry != null &&
        (firstEntry.totalItems > 0 || firstEntry.checklistInstanceId != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.check, size: 14, color: AppColors.white),
          ),
          const SizedBox(width: 8),
          const Text('Confirmed Schedule',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        _labelRow('Store', group.storeName),
        const SizedBox(height: 6),
        _labelRow('Work Role', group.workRoleName),
        const SizedBox(height: 12),
        ...group.timeBlocks.map((tb) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${tb.start} - ${tb.end}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success),
                ),
              ),
            )),
        const SizedBox(height: 4),
        Center(
          child: Text('Net work: $totalDisplay',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ),
        if (hasChecklist) ...[
          const SizedBox(height: 12),
          Builder(builder: (ctx) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final entryDate = DateTime(firstEntry!.workDate.year, firstEntry.workDate.month, firstEntry.workDate.day);
            final isFuture = entryDate.isAfter(today);
            final isPast = entryDate.isBefore(today);

            final label = isFuture ? 'Upcoming Checklist' : 'View Checklist';
            final color = isFuture ? AppColors.textMuted : AppColors.accent;
            final bg = isFuture ? AppColors.bg : AppColors.accentBg;

            return GestureDetector(
              onTap: isFuture ? null : () {
                Navigator.of(ctx).pop(); // 바텀시트 닫기
                if (isPast) {
                  // Past 탭으로 이동 후 해당 체크리스트 열기
                  context.go('/work?tab=past&scheduleId=${firstEntry.id}');
                } else {
                  // Today 탭 → 해당 체크리스트로 이동
                  context.go('/work?scheduleId=${firstEntry.id}');
                }
              },
              child: Opacity(
                opacity: isFuture ? 0.5 : 1.0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.checklist_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                    ),
                    if (!isFuture)
                      Icon(Icons.chevron_right, size: 18, color: color),
                  ]),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _requestSection(ScheduleRequest r) {
    final (color, bg) = _statusColors(r.status);
    final label = _statusLabel(r.status);
    final isModified = r.status == 'modified';
    final start = r.preferredStartTime ?? '';
    final end = r.preferredEndTime ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              r.status == 'rejected'
                  ? Icons.close
                  : isModified
                      ? Icons.edit
                      : Icons.schedule,
              size: 14,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label Schedule',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        _labelRow('Store', r.storeName ?? ''),
        const SizedBox(height: 6),
        _labelRow('Work Role', r.workRoleName ?? ''),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '$start - $end',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        if (r.note != null && r.note!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('"${r.note}"',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic)),
        ],
        // Change comparison box for modified
        if (isModified && r.originalStartTime != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    const Text(
                      'Changed by manager',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(
                      width: 40,
                      child: Text('Time',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ),
                    Text(
                      '${r.originalStartTime}–${r.originalEndTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('→',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.warning)),
                    const SizedBox(width: 6),
                    Text(
                      '$start–$end',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Rejection reason
        if (r.status == 'rejected' && r.rejectedReason != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(r.rejectedReason!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.danger))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _labelRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _emptyState() {
    // read-only mode — "Tap to request" CTA 제거, 단순 empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today_outlined,
              size: 36, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No schedule',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ────── Helpers ──────

String _statusLabel(String status) {
  switch (status) {
    case 'confirmed':
    case 'approved':
    case 'accepted':
      return 'Confirmed';
    case 'rejected':
      return 'Rejected';
    case 'modified':
      return 'Modified';
    case 'submitted':
      return 'Submitted';
    default:
      return 'Pending';
  }
}

(Color, Color) _statusColors(String status) {
  switch (status) {
    case 'confirmed':
    case 'approved':
    case 'accepted':
      return (AppColors.success, AppColors.successBg);
    case 'rejected':
      return (AppColors.danger, AppColors.dangerBg);
    case 'modified':
      return (AppColors.warning, AppColors.warningBg);
    default:
      return (AppColors.accent, AppColors.accentBg);
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _trimTime(String t) {
  if (t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  return '${parts[0]}:${parts[1]}';
}

double _parseHour(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) + (int.tryParse(parts[1]) ?? 0) / 60.0;
}

int _estimateMinutes(ScheduleRequest r) {
  if (r.preferredStartTime == null || r.preferredEndTime == null) return 0;
  final s = _parseHour(r.preferredStartTime!);
  var e = _parseHour(r.preferredEndTime!);
  // 자정 넘김: end <= start → +24h
  if (e <= s) e += 24;
  return ((e - s) * 60).round();
}
