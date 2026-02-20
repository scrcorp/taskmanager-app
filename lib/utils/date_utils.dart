import 'package:intl/intl.dart';

// ── Category A: Fixed Date ──────────────────────────────────────────
// No timezone conversion — the date itself is meaningful (work_date, due_date)

/// Format a fixed date without timezone conversion.
/// e.g., "Feb 19, 2026"
String formatFixedDate(DateTime date) =>
    DateFormat('MMM d, yyyy').format(DateTime(date.year, date.month, date.day));

/// Format a fixed date with weekday.
/// e.g., "Wed, Feb 19"
String formatFixedDateWithDay(DateTime date) =>
    DateFormat('EEE, MMM d').format(DateTime(date.year, date.month, date.day));

// ── Category B: Audit Timestamp ─────────────────────────────────────
// UTC → local timezone conversion (created_at, updated_at)

/// Format an audit timestamp as date only (converted to local).
/// e.g., "Feb 19, 2026"
String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date.toLocal());

/// Format an audit timestamp with date and time (converted to local).
/// e.g., "Feb 19, 3:30 PM"
String formatDateTime(DateTime date) => DateFormat('MMM d, h:mm a').format(date.toLocal());

/// Format weekday from a date.
/// e.g., "Wednesday"
String formatWeekday(DateTime date) => DateFormat('EEEE').format(date);

// ── Category C: Action Timestamp ────────────────────────────────────
// UTC → local timezone, time-focused display (completed_at, etc.)

/// Format an action timestamp with time emphasis.
/// Same day as [referenceDate]: "3:30 PM", different day: "2/19, 3:30 PM".
String formatActionTime(DateTime date, {DateTime? referenceDate}) {
  final local = date.toLocal();
  final ref = referenceDate?.toLocal() ?? DateTime.now();
  final sameDay = local.year == ref.year &&
      local.month == ref.month &&
      local.day == ref.day;

  if (sameDay) {
    return DateFormat('h:mm a').format(local);
  }
  return DateFormat('M/d, h:mm a').format(local);
}

/// Return a relative time string (e.g., "2h ago").
String timeAgo(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date.toLocal());

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';

  return formatDate(date);
}
