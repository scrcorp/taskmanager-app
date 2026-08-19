/// 시프트 달력 날짜 판정 유닛 테스트 — 앱 단일 출처(`shift_date_logic.dart`).
///
/// 고정하려는 것:
///   1. `so = 시작 < day_start(영업일+1) ? 1 : 0` — 경계 직전/직후/동일값
///   2. 요일별 경계
///   3. **시각만 바꿔도 날짜가 따라 움직인다** (경계 11:00 매장 09:00 ↔ 17:00 양방향).
///      이것이 2026-08 오염 24건의 정확한 재현 시나리오다.
///   4. 오프셋 기준은 **영업일** — 종료 날짜도 영업일 기준으로 읽힌다.
///   5. 저장용 벽시계 ISO 문자열(타임존 표기 없음, 자정 넘김 = 날짜 증가)

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/utils/schedule_edit_logic.dart';
import 'package:attendance/utils/shift_date_logic.dart';

/// 경계 11:00 매장 (이번 사고 매장의 형태).
final _eleven = DayStartConfig.tryParse({'all': '11:00'})!;

/// 영업일 2026-08-10 (월).
final _aug10 = DateTime(2026, 8, 10);

void main() {
  group('DayStartConfig', () {
    test('단일 문자열 / all / 요일별 세 형태를 모두 읽는다', () {
      expect(DayStartConfig.tryParse('11:00')!.minutesFor(_aug10), 11 * 60);
      expect(DayStartConfig.tryParse({'all': '06:00'})!.minutesFor(_aug10), 6 * 60);

      final perDay = DayStartConfig.tryParse({
        'mon': '11:00', 'tue': '05:00', 'wed': '06:00', 'thu': '06:00',
        'fri': '06:00', 'sat': '06:00', 'sun': '06:00',
      })!;
      expect(perDay.minutesFor(DateTime(2026, 8, 10)), 11 * 60); // Mon
      expect(perDay.minutesFor(DateTime(2026, 8, 11)), 5 * 60); // Tue
    });

    test('읽을 수 없으면 null — 그때 화면은 날짜를 짐작하지 않는다', () {
      expect(DayStartConfig.tryParse(null), isNull);
      expect(DayStartConfig.tryParse(const {}), isNull);
      expect(DayStartConfig.tryParse('nope'), isNull);
      expect(DayStartConfig.tryParse(42), isNull);
    });
  });

  group('시작 오프셋 so — 경계값', () {
    int so(int minutes, {DayStartConfig? cfg}) => autoStartOffsetDays(
          operatingDay: _aug10,
          dayStart: cfg ?? _eleven,
          startMinutes: minutes,
        );

    test('경계 직전은 다음 날, 경계 동일·직후는 영업일 당일', () {
      expect(so(10 * 60 + 55), 1); // 10:55 < 11:00
      expect(so(11 * 60), 0); // 11:00 — 경계 자신은 영업일 쪽
      expect(so(11 * 60 + 5), 0);
    });

    test('사고 재현 — 09:00 은 +1, 17:00 은 당일', () {
      expect(so(9 * 60), 1);
      expect(so(17 * 60), 0);
    });

    test('요일별 경계는 **영업일+1 의 요일** 값을 본다', () {
      // 영업일 Mon 8/10 → 경계는 Tue 8/11 의 05:00 을 본다.
      final perDay = DayStartConfig.tryParse({
        'mon': '11:00', 'tue': '05:00', 'wed': '06:00', 'thu': '06:00',
        'fri': '06:00', 'sat': '06:00', 'sun': '06:00',
      })!;
      expect(so(6 * 60, cfg: perDay), 0); // 06:00 >= 05:00 → 당일
      expect(so(4 * 60, cfg: perDay), 1); // 04:00 < 05:00 → 다음 날
    });
  });

  group('resolveShiftDates — 영업일 기준 오프셋', () {
    ShiftDates dates(int startMinutes, int durationMinutes, {int? override}) =>
        resolveShiftDates(
          operatingDay: _aug10,
          dayStart: _eleven,
          times: ShiftTimes(
              startMinutes: startMinutes, durationMinutes: durationMinutes),
          startOffsetOverride: override,
        );

    test('경계 이후 주간 근무 — 두 끝점 모두 영업일 당일', () {
      final d = dates(12 * 60, 8 * 60); // 12:00 ~ 20:00
      expect(d.startOffsetDays, 0);
      expect(d.endOffsetDays, 0);
      expect(d.startDate, DateTime(2026, 8, 10));
      expect(d.endDate, DateTime(2026, 8, 10));
      expect(d.isStartDateOverridden, isFalse);
    });

    test('경계 이전 시작 — **시작**이 영업일+1 (예전 기준으로는 표현 불가)', () {
      final d = dates(9 * 60, 8 * 60); // 09:00 ~ 17:00
      expect(d.startOffsetDays, 1);
      expect(d.endOffsetDays, 1); // 종료도 같은 날
      expect(d.startDate, DateTime(2026, 8, 11));
      expect(d.endDate, DateTime(2026, 8, 11));
    });

    test('자정 넘김 — 종료만 하루 뒤', () {
      final d = dates(20 * 60, 6 * 60); // 20:00 ~ 02:00
      expect(d.startOffsetDays, 0);
      expect(d.endOffsetDays, 1);
      expect(d.endDate, DateTime(2026, 8, 11));
    });

    test('시각을 바꾸면 날짜가 따라 움직인다 — 09:00 ↔ 17:00 양방향', () {
      var t = const ShiftTimes(startMinutes: 9 * 60, durationMinutes: 8 * 60);
      var d = resolveShiftDates(operatingDay: _aug10, dayStart: _eleven, times: t);
      expect(d.startDate, DateTime(2026, 8, 11)); // +1

      t = t.withStart(17 * 60);
      d = resolveShiftDates(operatingDay: _aug10, dayStart: _eleven, times: t);
      expect(d.startDate, DateTime(2026, 8, 10)); // 당일로 되돌아온다
      expect(d.endDate, DateTime(2026, 8, 11)); // 01:00 종료 → 자정 넘김

      t = t.withStart(9 * 60);
      d = resolveShiftDates(operatingDay: _aug10, dayStart: _eleven, times: t);
      expect(d.startDate, DateTime(2026, 8, 11)); // 반대 방향도 같다
    });

    test('사람이 고른 시작 날짜는 자동값을 이기고, 그 사실이 드러난다', () {
      final d = dates(9 * 60, 8 * 60, override: 0);
      expect(d.autoStartOffsetDays, 1);
      expect(d.startOffsetDays, 0);
      expect(d.startDate, DateTime(2026, 8, 10));
      expect(d.isStartDateOverridden, isTrue); // → date_override:true 로 나간다
    });

    test('24시간 이상 근무도 날짜가 접히지 않는다', () {
      final d = dates(12 * 60, 26 * 60);
      expect(d.endOffsetFromStartDate, 1);
      expect(d.endDate, DateTime(2026, 8, 11));
    });

    test('휴게 날짜는 근무 시작을 따라간다', () {
      final d = resolveShiftDates(
        operatingDay: _aug10,
        dayStart: _eleven,
        times: const ShiftTimes(
          startMinutes: 20 * 60,
          durationMinutes: 6 * 60,
          breakWindow: BreakWindow(startOffsetMinutes: 5 * 60, durationMinutes: 30),
        ),
      );
      // 20:00 시작 + 5h = 01:00 → 달력상 다음 날
      final times = const ShiftTimes(
        startMinutes: 20 * 60,
        durationMinutes: 6 * 60,
        breakWindow: BreakWindow(startOffsetMinutes: 5 * 60, durationMinutes: 30),
      );
      expect(d.breakStartDate(times), DateTime(2026, 8, 11));
      expect(d.breakEndDate(times), DateTime(2026, 8, 11));
      expect(d.breakStartOffsetDays(times), 1);
    });
  });

  group('wallClockIso — 저장 계약', () {
    test('타임존 표기 없이 벽시계 그대로', () {
      expect(wallClockIso(DateTime(2026, 8, 10), 9 * 60), '2026-08-10T09:00');
      expect(wallClockIso(DateTime(2026, 8, 10), 17 * 60), '2026-08-10T17:00');
    });

    test('자정을 넘으면 날짜가 증가한다 (24 초과 표기를 쓰지 않는다)', () {
      expect(wallClockIso(DateTime(2026, 8, 10), 26 * 60), '2026-08-11T02:00');
      expect(wallClockIso(DateTime(2026, 8, 10), 48 * 60), '2026-08-12T00:00');
    });

    test('월말을 넘어가도 달력이 맞는다', () {
      expect(wallClockIso(DateTime(2026, 8, 31), 25 * 60), '2026-09-01T01:00');
    });
  });
}
