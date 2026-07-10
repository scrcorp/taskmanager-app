/// Home screen schedule summary card
///
/// Shows this week's schedule overview: status counts, next shift info,
/// and rejected alert. Uses schedule provider data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:htm_core/htm_core.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/schedule.dart';
import '../../../providers/schedule_provider.dart';

class ScheduleSummaryCard extends ConsumerStatefulWidget {
  final VoidCallback? onViewAll;
  final VoidCallback? onResubmit;

  const ScheduleSummaryCard({
    super.key,
    this.onViewAll,
    this.onResubmit,
  });

  @override
  ConsumerState<ScheduleSummaryCard> createState() =>
      _ScheduleSummaryCardState();
}

class _ScheduleSummaryCardState extends ConsumerState<ScheduleSummaryCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(scheduleProvider.notifier);
      // Initialize if not already loaded
      if (ref.read(scheduleProvider).entries.isEmpty &&
          ref.read(scheduleProvider).requests.isEmpty &&
          !ref.read(scheduleProvider).isLoading) {
        notifier.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final state = ref.watch(scheduleProvider);

    if (state.isLoading && state.entries.isEmpty && state.requests.isEmpty) {
      return _buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          ),
        ),
      );
    }

    // Calculate stats for this week
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weekEntries = state.entries.where((e) =>
        !e.workDate.isBefore(weekStart) && !e.workDate.isAfter(weekEnd));
    final weekRequests = state.requests.where((r) =>
        !r.workDate.isBefore(weekStart) && !r.workDate.isAfter(weekEnd));

    int confirmed = 0;
    for (final e in weekEntries) {
      confirmed++;
    }
    // Deduplicate: entries already counted, don't count accepted requests
    final entryDates =
        weekEntries.map((e) => _fmt(e.workDate)).toSet();

    int modified = 0, submitted = 0, rejected = 0;
    ScheduleRequest? firstRejected;
    for (final r in weekRequests) {
      switch (r.status) {
        case 'modified':
          modified++;
          break;
        case 'submitted':
          submitted++;
          break;
        case 'rejected':
          rejected++;
          firstRejected ??= r;
          break;
      }
    }

    // Find next shift
    final todayStr = _fmt(now);
    final currentHour = now.hour + now.minute / 60.0;

    // Check entries for next shift
    _NextShift? nextShift;
    final futureEntries = state.entries
        .where((e) =>
            !e.workDate.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) {
        final cmp = a.workDate.compareTo(b.workDate);
        if (cmp != 0) return cmp;
        return a.startTime.compareTo(b.startTime);
      });

    for (final e in futureEntries) {
      final eDate = _fmt(e.workDate);
      final startH = _parseHour(e.startTime);
      // startAt(실제 순간)이 있으면 그것으로 과거 판정 — 새벽 근무(라벨=오늘,
      // 실제=내일 02:00)를 시각 문자열만 보고 과거로 오판해 스킵하던 버그 수정.
      final started = e.startAt != null
          ? e.startAt!.isBefore(now)
          : (eDate == todayStr && startH < currentHour);
      if (started) continue;
      // 표시 라벨은 실제 출근 달력일 기준 (직원이 "언제 나가야 하는지")
      final actualDay = e.startAt != null
          ? DateTime(e.startAt!.year, e.startAt!.month, e.startAt!.day)
          : e.workDate;
      final aDate = _fmt(actualDay);
      final isToday = aDate == todayStr;
      final isTomorrow = aDate ==
          _fmt(DateTime(now.year, now.month, now.day + 1));
      final dayLabel = isToday
          ? t.scheduleToday
          : isTomorrow
              ? t.homeTomorrow
              : '${DateFormat.E(localeStr).format(actualDay)} ${actualDay.month}/${actualDay.day}';
      nextShift = _NextShift(
        dayLabel: dayLabel,
        startTime: e.startTime,
        endTime: e.endTime,
        breakStartTime: e.breakStartTime,
        breakEndTime: e.breakEndTime,
        storeName: e.storeName ?? '',
        roleName: e.workRoleName ?? '',
        hours: '${e.netWorkMinutes ~/ 60}h',
      );
      break;
    }

    // Also check modified requests as next shift
    if (nextShift == null) {
      final futureRequests = state.requests
          .where((r) =>
              (r.status == 'modified' || r.status == 'submitted') &&
              !r.workDate
                  .isBefore(DateTime(now.year, now.month, now.day)))
          .toList()
        ..sort((a, b) => a.workDate.compareTo(b.workDate));
      for (final r in futureRequests) {
        if (r.preferredStartTime == null) continue;
        final rDate = _fmt(r.workDate);
        final startH = _parseHour(r.preferredStartTime!);
        if (rDate == todayStr && startH < currentHour) continue;
        final isToday = rDate == todayStr;
        final isTomorrow = rDate ==
            _fmt(DateTime(now.year, now.month, now.day + 1));
        final dayLabel = isToday
            ? t.scheduleToday
            : isTomorrow
                ? t.homeTomorrow
                : '${DateFormat.E(localeStr).format(r.workDate)} ${r.workDate.month}/${r.workDate.day}';
        nextShift = _NextShift(
          dayLabel: dayLabel,
          startTime: r.preferredStartTime!,
          endTime: r.preferredEndTime ?? '',
          storeName: r.storeName ?? '',
          roleName: r.workRoleName ?? '',
          hours: '',
        );
        break;
      }
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.homeScheduleHeader,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (widget.onViewAll != null)
                GestureDetector(
                  onTap: widget.onViewAll,
                  child: Text(
                    t.homeViewAll,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats grid
          Row(
            children: [
              _statBox('$confirmed', t.scheduleStatusConfirmed, AppColors.success),
              const SizedBox(width: 10),
              _statBox('$modified', t.homeStatChanged, AppColors.warning),
              const SizedBox(width: 10),
              _statBox('$submitted', t.scheduleStatusPending, AppColors.accent),
            ],
          ),
          // Next shift
          if (nextShift != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.homeNextShift,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${nextShift.dayLabel} ${nextShift.startTime} ${nextShift.storeName} ${nextShift.roleName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${nextShift.timeLabel}${nextShift.hours.isNotEmpty ? ' · ${nextShift.hours}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Rejected alert
          if (rejected > 0 && firstRejected != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(16),
                border: const Border(
                    left: BorderSide(color: AppColors.danger, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        t.homeRejectedRequests(rejected),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat.E(localeStr).format(firstRejected.workDate)} ${firstRejected.workDate.month}/${firstRejected.workDate.day} '
                    '${firstRejected.storeName ?? ''} ${firstRejected.workRoleName ?? ''}'
                    '${firstRejected.rejectedReason != null ? ' — ${firstRejected.rejectedReason}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (widget.onResubmit != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: widget.onResubmit,
                      child: Text(
                        t.homeResubmit,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextShift {
  final String dayLabel;
  final String startTime;
  final String endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final String storeName;
  final String roleName;
  final String hours;

  _NextShift({
    required this.dayLabel,
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    required this.storeName,
    required this.roleName,
    required this.hours,
  });

  bool get hasBreak => breakStartTime != null && breakEndTime != null &&
      breakStartTime!.isNotEmpty && breakEndTime!.isNotEmpty;

  String get timeLabel => hasBreak
      ? '$startTime–$breakStartTime · $breakEndTime–$endTime'
      : '$startTime – $endTime';
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double _parseHour(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) + (int.tryParse(parts[1]) ?? 0) / 60.0;
}

