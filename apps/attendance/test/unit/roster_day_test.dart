/// 영업일 이동(F5)의 순수 로직.
///
/// 고정하려는 계약:
///   1. 오늘이 아닌 날은 **반드시** 상대 라벨이 나온다 (오늘로 착각하면 위험).
///   2. 오늘을 모를 때도 아무 표시 없이 넘어가지 않는다.
///   3. 서버에 보내는 날짜 형식은 "YYYY-MM-DD" 고정.

import 'package:attendance/utils/roster_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 10); // Mon

  test('operatingDayParam — 한 자리 월/일도 0 을 채운다', () {
    expect(operatingDayParam(DateTime(2026, 8, 9)), '2026-08-09');
    expect(operatingDayParam(DateTime(2026, 12, 31)), '2026-12-31');
    // 시분초가 붙어 있어도 날짜만 나간다 (서버는 date 로 파싱한다).
    expect(operatingDayParam(DateTime(2026, 8, 9, 23, 30)), '2026-08-09');
  });

  test('rosterDayLabel — 요일 + 월 + 일', () {
    expect(rosterDayLabel(DateTime(2026, 8, 10)), 'Mon, Aug 10');
    expect(rosterDayLabel(DateTime(2026, 8, 16)), 'Sun, Aug 16');
  });

  test('오늘이면 상대 라벨이 없다 (= 강조할 것 없음)', () {
    expect(rosterRelativeLabel(today, today), isNull);
    // 시분이 붙어 있어도 같은 날이면 오늘이다.
    expect(rosterRelativeLabel(DateTime(2026, 8, 10, 23, 59), today), isNull);
    expect(isRosterToday(today, today), isTrue);
  });

  test('오늘이 아니면 항상 상대 라벨이 나온다', () {
    expect(rosterRelativeLabel(DateTime(2026, 8, 9), today), 'Yesterday');
    expect(rosterRelativeLabel(DateTime(2026, 8, 11), today), 'Tomorrow');
    expect(rosterRelativeLabel(DateTime(2026, 8, 13), today), '+3 days');
    expect(rosterRelativeLabel(DateTime(2026, 8, 7), today), '3 days ago');
  });

  test('오늘을 모르면 오늘로 단정하지 않는다', () {
    // work_date 미수신 상태. "표시 없음"은 오늘처럼 보이므로 금지.
    expect(rosterRelativeLabel(today, null), 'Selected day');
    expect(isRosterToday(today, null), isFalse);
    expect(rosterDayDelta(today, null), isNull);
  });

  test('제목/빈 상태 문구 — 오늘이면 기존 문구 유지', () {
    expect(rosterTitle(today, today), "Today's Schedules");
    expect(rosterTitle(DateTime(2026, 8, 12), today), 'Schedules · Wed, Aug 12');
    expect(rosterEmptyTitle(today, today), 'No schedules for today');
    expect(rosterEmptyTitle(DateTime(2026, 8, 12), today),
        'No schedules for Wed, Aug 12');
  });
}
