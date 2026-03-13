/// Weekly timeline widget
///
/// 06:00-24:00 horizontal bar layout with schedule blocks per day.
/// Tap a block → popover tooltip with summary. "Details >" → full bottom sheet.
/// Supports confirmed/submitted/modified/rejected status variants,
/// ghost blocks for modified originals, now line, and multi-row tracks.
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/schedule.dart';

const _tlStart = 6.0;
const _tlEnd = 24.0;
const _tlHours = _tlEnd - _tlStart;
const _narrowThreshold = 3.5;
const _rowHeight = 60.0;
const _multiRowHeight = 104.0;
const _dowWidth = 36.0;

const _hourMarkers = [6, 9, 12, 15, 18, 21, 24];
const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// A unified item representing either a confirmed entry or a request
class TimelineItem {
  final String storeName;
  final String roleName;
  final String status;
  final double startHour; // visual bar: min start
  final double endHour; // visual bar: max end
  final double? originalStartHour;
  final double? originalEndHour;
  final String? rejectedReason;
  final int netMinutes;
  final DateTime date;
  /// Individual time blocks (for break-split entries)
  final List<({String start, String end})> timeBlocks;

  TimelineItem({
    required this.storeName,
    required this.roleName,
    required this.status,
    required this.startHour,
    required this.endHour,
    this.originalStartHour,
    this.originalEndHour,
    this.rejectedReason,
    this.netMinutes = 0,
    required this.date,
    this.timeBlocks = const [],
  });
}

class WeeklyTimeline extends StatefulWidget {
  final DateTime weekStart;
  final List<ScheduleEntry> entries;
  final List<ScheduleRequest> requests;
  final void Function(DateTime date) onDayTap;
  final void Function(DateTime date) onDayDetailTap;

  const WeeklyTimeline({
    super.key,
    required this.weekStart,
    required this.entries,
    required this.requests,
    required this.onDayTap,
    required this.onDayDetailTap,
  });

  @override
  State<WeeklyTimeline> createState() => _WeeklyTimelineState();
}

class _WeeklyTimelineState extends State<WeeklyTimeline> {
  OverlayEntry? _popover;
  TimelineItem? _activeItem;

  void _dismissPopover() {
    _popover?.remove();
    _popover = null;
    _activeItem = null;
  }

  void _showPopover(BuildContext blockContext, TimelineItem item) {
    _dismissPopover();
    _activeItem = item;

    final overlay = Overlay.of(context);
    final box = blockContext.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final blockSize = box.size;

    _popover = OverlayEntry(builder: (ctx) {
      return _PopoverOverlay(
        blockRect: Rect.fromLTWH(pos.dx, pos.dy, blockSize.width, blockSize.height),
        item: item,
        onDismiss: _dismissPopover,
        onDetailsTap: () {
          _dismissPopover();
          widget.onDayDetailTap(item.date);
        },
      );
    });
    overlay.insert(_popover!);
  }

  @override
  void dispose() {
    _dismissPopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimeAxis(),
        ...List.generate(7, (i) {
          final date = widget.weekStart.add(Duration(days: i));
          return _TimelineRow(
            date: date,
            items: _itemsForDate(date),
            onEmptyTap: () => widget.onDayTap(date),
            onBlockTap: (blockCtx, item) => _showPopover(blockCtx, item),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  List<TimelineItem> _itemsForDate(DateTime date) {
    final ds = _fmt(date);
    final items = <TimelineItem>[];

    final dayEntries =
        widget.entries.where((e) => _fmt(e.workDate) == ds).toList();
    final groupMap = <String, List<ScheduleEntry>>{};
    for (final e in dayEntries) {
      final key = '${e.storeName ?? ''}-${e.workRoleName ?? ''}';
      groupMap.putIfAbsent(key, () => []).add(e);
    }
    for (final group in groupMap.values) {
      double minStart = 24;
      double maxEnd = 0;
      int totalMin = 0;
      final blocks = <({String start, String end})>[];
      for (final e in group) {
        minStart = min(minStart, _parseHour(e.startTime));
        maxEnd = max(maxEnd, _parseHour(e.endTime));
        totalMin += e.netWorkMinutes;
        blocks.add((start: e.startTime, end: e.endTime));
      }
      items.add(TimelineItem(
        storeName: group.first.storeName ?? '',
        roleName: group.first.workRoleName ?? '',
        status: 'confirmed',
        startHour: minStart,
        endHour: maxEnd,
        netMinutes: totalMin,
        date: date,
        timeBlocks: blocks,
      ));
    }

    // Requests: skip accepted (already shown as entry),
    // skip submitted if matching entry exists for same store+time
    final dayRequests =
        widget.requests.where((r) => _fmt(r.workDate) == ds).toList();
    for (final r in dayRequests) {
      // accepted requests are already represented as entries
      if (r.status == 'accepted') continue;

      final start = r.preferredStartTime ?? '';
      final end = r.preferredEndTime ?? '';
      if (start.isEmpty || end.isEmpty) continue;

      // skip submitted request if a matching entry exists (same store + overlapping time)
      if (r.status == 'submitted') {
        final hasEntry = dayEntries.any((e) =>
            (e.storeName ?? '') == (r.storeName ?? '') &&
            e.startTime == start &&
            e.endTime == end);
        if (hasEntry) continue;
      }

      double? origStart;
      double? origEnd;
      if (r.status == 'modified' && r.originalStartTime != null) {
        origStart = _parseHour(r.originalStartTime!);
        origEnd = _parseHour(r.originalEndTime ?? r.originalStartTime!);
      }
      final sh = _parseHour(start);
      final eh = _parseHour(end);
      items.add(TimelineItem(
        storeName: r.storeName ?? '',
        roleName: r.workRoleName ?? '',
        status: r.status,
        startHour: sh,
        endHour: eh,
        originalStartHour: origStart,
        originalEndHour: origEnd,
        rejectedReason: r.rejectedReason,
        netMinutes: ((eh - sh) * 60).round(),
        date: date,
      ));
    }

    return items;
  }
}

// ────── Popover Overlay ──────

class _PopoverOverlay extends StatelessWidget {
  final Rect blockRect;
  final TimelineItem item;
  final VoidCallback onDismiss;
  final VoidCallback onDetailsTap;

  const _PopoverOverlay({
    required this.blockRect,
    required this.item,
    required this.onDismiss,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    const popoverW = 220.0;
    const popoverH = 130.0;
    const arrowH = 8.0;

    // Position: prefer above the block, fallback below
    final showAbove = blockRect.top - popoverH - arrowH > 60;
    final popoverTop = showAbove
        ? blockRect.top - popoverH - arrowH
        : blockRect.bottom + arrowH;

    // Horizontal: center on block, clamp to screen
    var popoverLeft =
        blockRect.left + blockRect.width / 2 - popoverW / 2;
    popoverLeft = popoverLeft.clamp(12.0, screenW - popoverW - 12);

    // Arrow horizontal position relative to popover
    final arrowLeft =
        (blockRect.left + blockRect.width / 2 - popoverLeft).clamp(16.0, popoverW - 16);

    final (statusColor, statusBg) = _popoverStatusColors(item.status);
    final statusLabel = _popoverStatusLabel(item.status);
    final timeStr = '${_fmtHour(item.startHour)} – ${_fmtHour(item.endHour)}';
    final hours = item.netMinutes >= 60
        ? '${item.netMinutes ~/ 60}h${item.netMinutes % 60 > 0 ? ' ${item.netMinutes % 60}m' : ''}'
        : '${item.netMinutes}m';

    return Stack(
      children: [
        // Dismiss barrier
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // Popover card
        Positioned(
          left: popoverLeft,
          top: popoverTop,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                if (!showAbove)
                  // Arrow pointing up
                  Padding(
                    padding: EdgeInsets.only(left: arrowLeft - 8),
                    child: CustomPaint(
                      size: const Size(16, arrowH),
                      painter: _ArrowPainter(isUp: true),
                    ),
                  ),
                Container(
                  width: popoverW,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status badge + store
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onDismiss,
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Store + role
                      Text(
                        item.storeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.roleName.isNotEmpty)
                        Text(
                          item.roleName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Time blocks (show individually if break-split)
                      if (item.timeBlocks.length > 1)
                        ...item.timeBlocks.map((tb) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 14, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${tb.start} – ${tb.end}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                      else
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Text(
                            'Net: $hours',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      // Changed info for modified
                      if (item.status == 'modified' &&
                          item.originalStartHour != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Was: ${_fmtHour(item.originalStartHour!)}–${_fmtHour(item.originalEndHour!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      // Rejection reason
                      if (item.status == 'rejected' &&
                          item.rejectedReason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.rejectedReason!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Details link
                      GestureDetector(
                        onTap: onDetailsTap,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right,
                                size: 16, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAbove)
                  // Arrow pointing down
                  Padding(
                    padding: EdgeInsets.only(left: arrowLeft - 8),
                    child: CustomPaint(
                      size: const Size(16, arrowH),
                      painter: _ArrowPainter(isUp: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  (Color, Color) _popoverStatusColors(String status) {
    switch (status) {
      case 'confirmed':
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

  String _popoverStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'submitted':
        return 'Pending';
      case 'modified':
        return 'Changed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

// ── Arrow Painter ──

class _ArrowPainter extends CustomPainter {
  final bool isUp;
  _ArrowPainter({required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Time Axis ──

class _TimeAxis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(left: _dowWidth + 12, right: 16, bottom: 4),
      child: SizedBox(
        height: 16,
        child: LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: _hourMarkers.map((h) {
              final pct = (h - _tlStart) / _tlHours;
              return Positioned(
                left: pct * w - 8,
                top: 0,
                child: Text(
                  h.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),
    );
  }
}

// ── Timeline Row ──

class _TimelineRow extends StatelessWidget {
  final DateTime date;
  final List<TimelineItem> items;
  final VoidCallback onEmptyTap;
  final void Function(BuildContext blockContext, TimelineItem item) onBlockTap;

  const _TimelineRow({
    required this.date,
    required this.items,
    required this.onEmptyTap,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final dow = date.weekday % 7;
    final isEmpty = items.isEmpty;
    final isMultiRow = items.length > 1;
    final trackHeight = isMultiRow ? _multiRowHeight : _rowHeight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEmpty ? onEmptyTap : null,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 3),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isToday ? AppColors.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Day label
            SizedBox(
              width: _dowWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[dow],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: dow == 0
                          ? AppColors.danger
                          : dow == 6
                              ? AppColors.accent
                              : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  isToday
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        )
                      : Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: dow == 0
                                ? AppColors.danger
                                : dow == 6
                                    ? AppColors.accent
                                    : AppColors.text,
                          ),
                        ),
                ],
              ),
            ),
            // Track
            Expanded(
              child: Container(
                height: trackHeight,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: LayoutBuilder(builder: (_, constraints) {
                  final trackW = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GridLines(width: trackW),
                      if (isEmpty)
                        const Center(
                          child: Text(
                            'Day off',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ...List.generate(items.length, (i) {
                        final item = items[i];
                        final widgets = <Widget>[];
                        if (item.status == 'modified' &&
                            item.originalStartHour != null) {
                          widgets.add(_ScheduleBlock(
                            item: TimelineItem(
                              storeName: item.storeName,
                              roleName: item.roleName,
                              status: 'ghost',
                              startHour: item.originalStartHour!,
                              endHour: item.originalEndHour!,
                              date: item.date,
                            ),
                            trackWidth: trackW,
                            trackHeight: trackHeight,
                            rowIndex: isMultiRow ? i : null,
                            totalRows: isMultiRow ? items.length : 1,
                          ));
                        }
                        widgets.add(_ScheduleBlock(
                          item: item,
                          trackWidth: trackW,
                          trackHeight: trackHeight,
                          rowIndex: isMultiRow ? i : null,
                          totalRows: isMultiRow ? items.length : 1,
                          onTap: item.status != 'ghost'
                              ? (ctx) => onBlockTap(ctx, item)
                              : null,
                        ));
                        return widgets;
                      }).expand((w) => w),
                      if (isToday) _NowLine(trackWidth: trackW),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Lines ──

class _GridLines extends StatelessWidget {
  final double width;
  const _GridLines({required this.width});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: List.generate(_tlHours.toInt(), (i) {
          final hour = _tlStart.toInt() + i;
          final isMajor = hour % 6 == 0;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.black
                        .withValues(alpha: isMajor ? 0.07 : 0.03),
                    width: 1,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Schedule Block ──

class _ScheduleBlock extends StatelessWidget {
  final TimelineItem item;
  final double trackWidth;
  final double trackHeight;
  final int? rowIndex;
  final int totalRows;
  final void Function(BuildContext ctx)? onTap;

  const _ScheduleBlock({
    required this.item,
    required this.trackWidth,
    required this.trackHeight,
    this.rowIndex,
    required this.totalRows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clampedStart = max(item.startHour, _tlStart);
    final clampedEnd = min(item.endHour, _tlEnd);
    final left = ((clampedStart - _tlStart) / _tlHours) * trackWidth;
    final blockW = ((clampedEnd - clampedStart) / _tlHours) * trackWidth;
    final duration = item.endHour - item.startHour;
    final isNarrow = duration <= _narrowThreshold;
    final isGhost = item.status == 'ghost';

    double top = 4;
    double bottom = 4;
    if (rowIndex != null && totalRows > 1) {
      final rowH = (trackHeight - 8) / totalRows;
      top = 4 + rowIndex! * rowH;
      bottom = trackHeight - top - rowH + 4;
    }

    final (fg, bg, border, isDashed) = _blockStyle(item.status);
    final statusLabel = _statusLabelFor(item.status);
    final hours =
        duration >= 1 ? '${duration.round()}h' : '${(duration * 60).round()}m';
    final timeStr = '${_fmtHour(item.startHour)}–${_fmtHour(item.endHour)}';

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      width: max(blockW, 8),
      child: Builder(builder: (blockCtx) {
        return GestureDetector(
          onTap: onTap != null ? () => onTap!(blockCtx) : null,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border:
                  isDashed ? null : Border.all(color: border, width: 1.5),
            ),
            foregroundDecoration:
                isDashed ? _DashedDecoration(color: border, radius: 6) : null,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: isGhost
                ? Center(
                    child: Text(
                      '${_fmtHour(item.startHour)}–${_fmtHour(item.endHour)}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  )
                : isNarrow
                    ? Center(
                        child: Text(
                          '${item.storeName.length > 4 ? item.storeName.substring(0, 4) : item.storeName} $timeStr',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: fg,
                            decoration: item.status == 'rejected'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.storeName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                    decoration: item.status == 'rejected'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.roleName.isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    item.roleName,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: fg.withValues(alpha: 0.8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: item.status == 'submitted'
                                      ? AppColors.accent
                                      : Colors.white
                                          .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color: item.status == 'submitted'
                                        ? Colors.white
                                        : fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: fg.withValues(alpha: 0.9),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                hours,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: fg.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        );
      }),
    );
  }

  (Color fg, Color bg, Color border, bool isDashed) _blockStyle(
      String status) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return (Colors.white, AppColors.success, AppColors.success, false);
      case 'submitted':
        return (
          AppColors.accent,
          AppColors.accentBg,
          AppColors.accent,
          true
        );
      case 'modified':
        return (Colors.white, AppColors.warning, AppColors.warning, false);
      case 'rejected':
        return (
          AppColors.danger,
          AppColors.dangerBg,
          AppColors.danger,
          false
        );
      case 'ghost':
        return (
          AppColors.warning.withValues(alpha: 0.6),
          AppColors.warningBg.withValues(alpha: 0.3),
          AppColors.warning.withValues(alpha: 0.4),
          true,
        );
      default:
        return (
          AppColors.accent,
          AppColors.accentBg,
          AppColors.accent,
          true
        );
    }
  }

  String _statusLabelFor(String status) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'submitted':
        return 'Pending';
      case 'modified':
        return 'Changed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

// ── Dashed border decoration ──

class _DashedDecoration extends Decoration {
  final Color color;
  final double radius;

  const _DashedDecoration({required this.color, required this.radius});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedPainter(color: color, radius: radius);
  }
}

class _DashedPainter extends BoxPainter {
  final Color color;
  final double radius;

  _DashedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);
    final dashPath = _dashPath(path, dashLength: 4, gapLength: 3);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source,
      {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = min(dashLength, metric.length - distance);
        dest.addPath(
            metric.extractPath(distance, distance + len), Offset.zero);
        distance += dashLength + gapLength;
      }
    }
    return dest;
  }
}

// ── Now Line ──

class _NowLine extends StatelessWidget {
  final double trackWidth;
  const _NowLine({required this.trackWidth});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60.0;
    if (hour < _tlStart || hour > _tlEnd) return const SizedBox.shrink();
    final left = ((hour - _tlStart) / _tlHours) * trackWidth;
    return Positioned(
      left: left - 1,
      top: -2,
      bottom: -2,
      child: SizedBox(
        width: 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Positioned(
              left: -3,
              top: -3,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──

double _parseHour(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) + (int.tryParse(parts[1]) ?? 0) / 60.0;
}

String _fmtHour(double h) {
  final hr = h.floor();
  final mn = ((h - hr) * 60).round();
  return '${hr.toString().padLeft(2, '0')}:${mn.toString().padLeft(2, '0')}';
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
