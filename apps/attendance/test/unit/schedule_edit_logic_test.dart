/// Unit tests — schedule_edit_logic (스케줄 시간 정책 D5-2/D5-3/D6).
///
/// 고정하려는 계약:
///   - 자정 넘김은 clamp 가 아니라 wrap (23:59 로 잘라 5분 grid 를 깨뜨리던 사고)
///   - 시작/종료/길이 갱신 규칙(D5-2) — 시작은 저절로 움직이지 않는다
///   - 어떤 조작 순서로도 시각이 5분 배수를 벗어나지 않는다

import 'package:attendance/utils/schedule_edit_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wrapMinutes', () {
    test('하루를 넘으면 다음 날로 감싼다', () {
      expect(wrapMinutes(20 * 60 + 330), 60 + 30); // 20:00 + 5.5h = 01:30 (+1)
      expect(wrapMinutes(1440), 0);
      expect(wrapMinutes(1445), 5);
    });
    test('음수도 안전하다', () {
      expect(wrapMinutes(-30), 23 * 60 + 30);
      expect(wrapMinutes(-1470), 23 * 60 + 30);
    });
  });

  group('clampMinutes', () {
    test('범위 제한 (휠 전용)', () {
      expect(clampMinutes(-5), 0);
      expect(clampMinutes(2000), 1439);
      expect(clampMinutes(600), 600);
    });
  });

  group('round5ToNow', () {
    test('5분 단위 반올림', () {
      expect(round5ToNow(DateTime(2026, 5, 29, 12, 52)), 12 * 60 + 50); // 12:52 → 12:50
      expect(round5ToNow(DateTime(2026, 5, 29, 12, 53)), 12 * 60 + 55); // 12:53 → 12:55
      expect(round5ToNow(DateTime(2026, 5, 29, 15, 22)), 15 * 60 + 20); // 15:22 → 15:20
    });
  });

  group('hhmmToMinutes / minutesToHHmm', () {
    test('왕복 변환', () {
      expect(hhmmToMinutes('09:30'), 570);
      expect(minutesToHHmm(570), '09:30');
      expect(minutesToHHmm(900), '15:00');
    });
    test('형식 이상 → null', () {
      expect(hhmmToMinutes(null), isNull);
      expect(hhmmToMinutes('abc'), isNull);
      expect(hhmmToMinutes('9'), isNull);
    });
  });

  group('snapToStep', () {
    test('가장 가까운 5분 배수로 스냅', () {
      expect(snapToStep(9 * 60 + 17), 9 * 60 + 15); // 09:17 → 09:15
      expect(snapToStep(9 * 60 + 18), 9 * 60 + 20); // 09:18 → 09:20
      expect(snapToStep(9 * 60 + 15), 9 * 60 + 15); // 이미 배수면 그대로
    });
    test('step 배수만 반환 — 서버가 거부할 값이 나오지 않는다', () {
      for (var m = 0; m <= 1439; m++) {
        expect(snapToStep(m) % scheduleStepMinutes, 0, reason: 'minutes=$m');
      }
    });
    test('상단 경계는 자르지 않고 감싼다 (23:58 → 00:00)', () {
      expect(snapToStep(1438), 0);
      expect(snapToStep(1439), 0);
    });
  });

  group('ShiftTimes — 갱신 규칙 (D5-2)', () {
    const base = ShiftTimes(startMinutes: 9 * 60, durationMinutes: 330); // 09:00 +5.5h

    test('종료는 시작 + 길이', () {
      expect(base.endMinutes, 14 * 60 + 30);
      expect(base.endDayOffset, 0);
      expect(base.isValid, isTrue);
    });

    test('시작 변경 → 길이 유지, 종료가 따라 움직인다', () {
      final moved = base.withStart(20 * 60);
      expect(moved.durationMinutes, 330);
      expect(moved.endMinutes, 60 + 30); // 01:30
      expect(moved.endDayOffset, 1); // "+1"
    });

    test('종료 변경 → 시작 유지, 길이가 따라 움직인다', () {
      final ended = base.withEnd(17 * 60);
      expect(ended.startMinutes, 9 * 60);
      expect(ended.durationMinutes, 8 * 60);
    });

    test('종료를 시작보다 이르게 → 자정 넘김으로 해석', () {
      final overnight = base.withEnd(2 * 60);
      expect(overnight.startMinutes, 9 * 60);
      expect(overnight.durationMinutes, 17 * 60);
      expect(overnight.endDayOffset, 1);
    });

    test('길이 변경 → 시작 유지, 종료가 따라 움직인다', () {
      final longer = base.withDuration(600);
      expect(longer.startMinutes, 9 * 60);
      expect(longer.endMinutes, 19 * 60);
    });

    test('저녁 시작도 종료가 잘리지 않는다 (18:30 이후 생성 실패 회귀)', () {
      // 예전엔 clamp 로 23:59 가 되어 5분 배수가 깨져 서버가 거부했다.
      for (var start = 18 * 60 + 30; start < 1440; start += scheduleStepMinutes) {
        final t = ShiftTimes(startMinutes: start, durationMinutes: fallbackShiftMinutes);
        expect(t.endMinutes % scheduleStepMinutes, 0, reason: 'start=$start');
        expect(t.durationMinutes, fallbackShiftMinutes, reason: 'start=$start');
      }
    });

    test('종료 == 시작 → 길이 0, 저장 불가로 표시한다 (임의 보정 금지)', () {
      final zero = base.withEnd(9 * 60);
      expect(zero.durationMinutes, 0);
      expect(zero.isValid, isFalse);
    });

    test('fromInstants 는 24시간 이상도 그대로 살린다', () {
      final t = ShiftTimes.fromInstants(
        DateTime(2026, 8, 10, 22, 0),
        DateTime(2026, 8, 12, 2, 0),
      );
      expect(t.startMinutes, 22 * 60);
      expect(t.durationMinutes, 28 * 60);
      expect(t.endMinutes, 2 * 60);
      expect(t.endDayOffset, 2); // +2일
    });

    test('fromStartEnd 는 종료 ≤ 시작을 자정 넘김으로 본다', () {
      final t = ShiftTimes.fromStartEnd(22 * 60, 2 * 60);
      expect(t.durationMinutes, 4 * 60);
    });
  });

  group('표기 — 벽시계 + 마커', () {
    test('24 초과 표기를 쓰지 않는다', () {
      expect(hhmmWithDayMarker(2 * 60, dayOffset: 1), '02:00 +1');
      expect(hhmmWithDayMarker(2 * 60), '02:00');
      expect(hhmmWithDayMarker(26 * 60, dayOffset: 1), '02:00 +1'); // wrap 후 표기
    });

    test('길이 라벨', () {
      expect(formatDurationLabel(330), '5h 30m');
      expect(formatDurationLabel(360), '6h');
      expect(formatDurationLabel(45), '45m');
      expect(formatDurationLabel(0), '0m');
    });

    test('dayOffsetFrom — 영업일 대비 며칠 뒤인가', () {
      final day = DateTime(2026, 8, 10);
      expect(dayOffsetFrom(day, DateTime(2026, 8, 10, 22, 0)), 0);
      expect(dayOffsetFrom(day, DateTime(2026, 8, 11, 2, 0)), 1);
      expect(dayOffsetFrom(day, DateTime(2026, 8, 12, 2, 0)), 2);
      expect(dayOffsetFrom(day, DateTime(2026, 8, 9, 22, 0)), 0); // 과거는 마커 없음
      expect(dayOffsetFrom(null, DateTime(2026, 8, 11)), 0);
      expect(dayOffsetFrom(day, null), 0);
    });
  });
}
