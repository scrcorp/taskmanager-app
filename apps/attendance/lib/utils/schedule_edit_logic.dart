/// Schedule Edit 모달의 순수 시간 로직 (Issue 10 Step 5) — unit test 가능하게 분리.

const defaultShiftMinutes = 330; // 5.5h

/// 키오스크 스케줄 시각의 최소 단위(분). 서버 KIOSK_STEP_MINUTES 와 같은 값이어야 한다 —
/// 어긋나면 UI 에서 고를 수 있는 값을 서버가 거부한다.
const scheduleStepMinutes = 5;

int clampMinutes(int n) => n < 0 ? 0 : (n > 1439 ? 1439 : n);

/// 분값을 가장 가까운 step 배수로 스냅 (0..1439 로 clamp).
/// 워크인처럼 step 을 벗어난 기존 값을 휠에 올릴 때 사용.
int snapToStep(int minutes) {
  final snapped = ((minutes + scheduleStepMinutes ~/ 2) ~/ scheduleStepMinutes) * scheduleStepMinutes;
  return clampMinutes(snapped > 1435 ? 1435 : snapped);
}

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

/// 현재 시각을 step 단위로 반올림한 분값.
int round5ToNow(DateTime now) => snapToStep(now.hour * 60 + now.minute);

/// New 모드 기본 종료 = 시작 + 5.5h (clamp).
int defaultEndMinutes(int startMin) => clampMinutes(startMin + defaultShiftMinutes);
