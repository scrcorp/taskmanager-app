/// 날짜/시간 포맷 유틸리티
///
/// 앱 전반에서 사용하는 날짜 표시 함수 모음.
/// 타임존 변환이 필요한 경우와 고정 날짜(UTC 무시)를 구분하여 처리.
import 'package:intl/intl.dart';

/// 고정 날짜 포맷 (타임존 변환 없음) — "Mar 5, 2026"
///
/// work_date처럼 시간 정보 없이 날짜만 의미하는 값에 사용.
/// toLocal() 하면 날짜가 변할 수 있으므로 년/월/일만 직접 추출.
String formatFixedDate(DateTime date) =>
    DateFormat('MMM d, yyyy').format(DateTime(date.year, date.month, date.day));

/// 고정 날짜 + 요일 포맷 — "Tue, Mar 5"
String formatFixedDateWithDay(DateTime date) =>
    DateFormat('EEE, MMM d').format(DateTime(date.year, date.month, date.day));

/// 감사 타임스탬프를 로컬 날짜로 포맷 — "Mar 5, 2026"
String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date.toLocal());

/// 감사 타임스탬프를 로컬 날짜+시간으로 포맷 — "Mar 5, 2:30 PM"
String formatDateTime(DateTime date) => DateFormat('MMM d, h:mm a').format(date.toLocal());

/// 요일만 포맷 — "Tuesday"
String formatWeekday(DateTime date) => DateFormat('EEEE').format(date);

/// 액션 타임스탬프 포맷 — 같은 날이면 시간만, 다른 날이면 날짜+시간
///
/// 체크리스트 완료 시각 등 최근 이벤트 표시에 적합.
/// [referenceDate]가 없으면 현재 시각 기준.
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

/// 상대적 시간 표시 — "just now", "5m ago", "2h ago", "3d ago" 등
///
/// 댓글, 알림 등에서 사용. 30일 이상이면 절대 날짜로 폴백.
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
