/// 휴게 편집(F6, B2/B4)의 순수 로직.
///
/// 고정하려는 계약:
///   1. 시작을 옮기면 휴게가 **같은 오프셋으로 함께** 움직인다 (동반 이동, B2).
///   2. 원치 않으면 지우고 다시 넣을 수 있다 (B4) — 지우기가 없으면 데드락이다.
///   3. 근무를 줄여 휴게가 밖으로 나가면 조용히 자르지 않고 **저장을 막는다**.
///   4. 자정 넘김 휴게는 `+1` 로 표기한다 (24 초과 표기 금지, D5-1).

import 'package:attendance/utils/schedule_edit_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 09:00~17:00, 12:00~12:30 휴게 (오프셋 +180, 길이 30)
  const day = ShiftTimes(
    startMinutes: 9 * 60,
    durationMinutes: 8 * 60,
    breakWindow: BreakWindow(startOffsetMinutes: 180, durationMinutes: 30),
  );

  group('동반 이동 (B2)', () {
    test('시작을 2시간 당기면 휴게도 2시간 당겨진다', () {
      final moved = day.withStart(7 * 60);
      expect(moved.breakStartMinutes, 10 * 60); // 10:00
      expect(moved.breakEndMinutes, 10 * 60 + 30);
      // 오프셋 자체는 그대로 — 이게 "같은 오프셋으로" 의 뜻이다.
      expect(moved.breakWindow!.startOffsetMinutes, 180);
      expect(moved.breakInsideShift, isTrue);
    });

    test('자정을 넘겨 밀면 휴게 표기가 +1 이 된다 (26:00 같은 표기 금지)', () {
      // 21:00 시작 + 4시간 오프셋 → 01:00 (+1)
      const night = ShiftTimes(
        startMinutes: 21 * 60,
        durationMinutes: 5 * 60,
        breakWindow: BreakWindow(startOffsetMinutes: 240, durationMinutes: 30),
      );
      expect(night.breakStartMinutes, 60); // 01:00
      expect(night.breakStartOffsetFromStartDate, 1);
      expect(hhmmWithDayMarker(night.breakStartMinutes!,
          dayOffset: night.breakStartOffsetFromStartDate), '01:00 +1');
      expect(night.breakInsideShift, isTrue);
    });

    test('종료/길이 변경은 휴게 오프셋을 건드리지 않는다', () {
      expect(day.withDuration(10 * 60).breakWindow, day.breakWindow);
      expect(day.withEnd(18 * 60).breakWindow, day.breakWindow);
    });
  });

  group('삭제와 재입력 (B4)', () {
    test('withoutBreak 이후엔 휴게 시각이 null — 저장 시 삭제로 나간다', () {
      final none = day.withoutBreak();
      expect(none.hasBreak, isFalse);
      expect(none.breakStartMinutes, isNull);
      expect(none.breakEndMinutes, isNull);
      expect(none.breakInsideShift, isTrue); // 휴게가 없으면 위반도 없다
    });

    test('withDefaultBreak — 근무 한가운데, 5분 배수', () {
      final b = day.withoutBreak().withDefaultBreak();
      expect(b.breakWindow!.durationMinutes, defaultBreakMinutes);
      expect(b.breakWindow!.startOffsetMinutes % scheduleStepMinutes, 0);
      expect(b.breakInsideShift, isTrue);
      expect(b.breakStartMinutes, 12 * 60 + 45); // 09:00 + 3h45m
    });

    test('근무가 기본 휴게보다 짧으면 근무 길이만큼만 넣는다 (넣자마자 에러 금지)', () {
      const short = ShiftTimes(startMinutes: 9 * 60, durationMinutes: 20);
      final b = short.withDefaultBreak();
      expect(b.breakWindow!.durationMinutes, 20);
      expect(b.breakInsideShift, isTrue);
    });
  });

  group('근무창 밖 판정', () {
    test('근무를 줄이면 휴게가 밖으로 나가고 저장이 막힌다 (조용히 자르지 않는다)', () {
      final shrunk = day.withDuration(60); // 09:00~10:00, 휴게는 12:00
      expect(shrunk.breakWindow, day.breakWindow); // 값은 그대로 남는다
      expect(shrunk.breakInsideShift, isFalse);
      expect(shrunk.isValid, isTrue); // 근무 자체는 멀쩡하다
      expect(shrunk.canSave, isFalse); // 그래도 저장은 막힌다
      // 해소 수단: 지우기
      expect(shrunk.withoutBreak().canSave, isTrue);
    });

    test('휴게 시작을 근무 시작보다 앞으로 두면 근무 밖으로 판정된다', () {
      final bad = day.withBreakStart(8 * 60); // 08:00 (근무는 09:00 시작)
      expect(bad.breakInsideShift, isFalse);
      expect(bad.canSave, isFalse);
    });

    test('휴게 끝이 근무 끝과 같으면 안에 있는 것으로 본다 (경계 포함)', () {
      final edge = day.withBreakStart(16 * 60 + 30); // 16:30~17:00
      expect(edge.breakInsideShift, isTrue);
      expect(edge.canSave, isTrue);
    });
  });

  group('휴게 시작/종료 규칙 (근무 시각과 같은 모양)', () {
    test('휴게 시작 변경 — 길이 유지, 종료가 따라 움직인다', () {
      final m = day.withBreakStart(13 * 60);
      expect(m.breakWindow!.durationMinutes, 30);
      expect(m.breakEndMinutes, 13 * 60 + 30);
    });

    test('휴게 종료 변경 — 시작 유지, 길이가 따라 움직인다', () {
      final m = day.withBreakEnd(13 * 60);
      expect(m.breakStartMinutes, 12 * 60);
      expect(m.breakWindow!.durationMinutes, 60);
    });

    test('휴게가 없으면 종료만 바꾸는 조작은 무시된다 (반쪽 휴게 금지)', () {
      final none = day.withoutBreak();
      expect(none.withBreakEnd(13 * 60).hasBreak, isFalse);
    });
  });

  group('서버 값 복원 (breakWindowFrom)', () {
    test('벽시계 datetime 이 있으면 그쪽이 정본 — 자정 넘김이 정확하다', () {
      final w = breakWindowFrom(
        shiftStartAt: DateTime(2026, 8, 10, 21, 0),
        breakStartAt: DateTime(2026, 8, 11, 1, 0),
        breakEndAt: DateTime(2026, 8, 11, 1, 30),
      );
      expect(w!.startOffsetMinutes, 240);
      expect(w.durationMinutes, 30);
    });

    test('HH:mm 만 있으면 근무 시작 기준으로 감아 복원한다', () {
      final w = breakWindowFrom(
        shiftStartMinutes: 21 * 60,
        breakStartMinutes: 60, // 01:00
        breakEndMinutes: 90,
      );
      expect(w!.startOffsetMinutes, 240);
      expect(w.durationMinutes, 30);
    });

    test('한쪽만 오면 휴게 없음 (서버가 짝을 강제한다)', () {
      expect(
        breakWindowFrom(shiftStartMinutes: 540, breakStartMinutes: 720),
        isNull,
      );
      expect(breakWindowFrom(), isNull);
    });
  });

  test('floorToStep — 오프셋은 올림하지 않는다 (근무창을 넘길 수 있다)', () {
    expect(floorToStep(14), 10);
    expect(floorToStep(15), 15);
    expect(floorToStep(0), 0);
  });
}
