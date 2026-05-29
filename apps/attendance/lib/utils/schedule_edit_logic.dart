/// Schedule Edit 모달의 순수 시간 로직 (Issue 10 Step 5) — unit test 가능하게 분리.

const defaultShiftMinutes = 330; // 5.5h

int clampMinutes(int n) => n < 0 ? 0 : (n > 1439 ? 1439 : n);

/// "HH:mm" → 분(0..1439). 형식 이상이면 null.
int? hhmmToMinutes(String? hhmm) {
  if (hhmm == null || !hhmm.contains(':')) return null;
  final p = hhmm.split(':');
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String minutesToHHmm(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// 현재 시각을 5분 단위로 반올림한 분값.
int round5ToNow(DateTime now) {
  final nm = now.hour * 60 + now.minute;
  return clampMinutes(((nm + 2) ~/ 5) * 5);
}

/// New 모드 기본 종료 = 시작 + 5.5h (clamp).
int defaultEndMinutes(int startMin) => clampMinutes(startMin + defaultShiftMinutes);
