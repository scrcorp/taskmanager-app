/// early_clock_in_logic unit tests — 조기 출근 강행 사유.

import 'package:attendance/models/early_clock_in_reason.dart';
import 'package:attendance/utils/early_clock_in_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canSubmitEarlyClockIn', () {
    test('reason 미선택 → false', () {
      expect(canSubmitEarlyClockIn(null, ''), isFalse);
      expect(canSubmitEarlyClockIn(null, 'anything'), isFalse);
    });

    test('프리셋 선택 → detail 없어도 true', () {
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.askedToComeEarly, ''),
        isTrue,
      );
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.coveringForSomeone, ''),
        isTrue,
      );
    });

    test('other + 빈 detail → false (공백만도 false)', () {
      expect(canSubmitEarlyClockIn(EarlyClockInReason.other, ''), isFalse);
      expect(canSubmitEarlyClockIn(EarlyClockInReason.other, '   '), isFalse);
    });

    test('other + 내용 있음 → true', () {
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.other, 'Bus came early'),
        isTrue,
      );
    });
  });

  group('earlyClockInReasonToSubmit', () {
    test('프리셋 → 라벨 텍스트를 그대로 보낸다 (서버가 자유 문자열로 기록)', () {
      expect(
        earlyClockInReasonToSubmit(EarlyClockInReason.askedToComeEarly, ''),
        'Asked to come in early',
      );
    });

    test('other → 사용자가 적은 문장 (trim)', () {
      expect(
        earlyClockInReasonToSubmit(EarlyClockInReason.other, '  Bus early  '),
        'Bus early',
      );
    });
  });

  group('formatEarlyBy', () {
    test('60분 미만 → 분만', () {
      expect(formatEarlyBy(45), '45m');
      expect(formatEarlyBy(1), '1m');
    });

    test('60분 이상 → 시간 + 분', () {
      expect(formatEarlyBy(60), '1h 0m');
      expect(formatEarlyBy(125), '2h 5m');
    });

    test('상한이 없으므로 몇 시간 전도 표시된다', () {
      expect(formatEarlyBy(600), '10h 0m');
    });

    test('0 이하 → 0m', () {
      expect(formatEarlyBy(0), '0m');
      expect(formatEarlyBy(-30), '0m');
    });
  });

  group('minutesEarlyFromDetail', () {
    test('int 그대로', () {
      expect(minutesEarlyFromDetail({'minutes_early': 120}), 120);
    });

    test('숫자 문자열도 파싱', () {
      expect(minutesEarlyFromDetail({'minutes_early': '90'}), 90);
    });

    test('detail 없음/키 없음/이상한 값 → 0 (화면이 깨지면 안 된다)', () {
      expect(minutesEarlyFromDetail(null), 0);
      expect(minutesEarlyFromDetail({}), 0);
      expect(minutesEarlyFromDetail({'minutes_early': 'abc'}), 0);
    });
  });
}
