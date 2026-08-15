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

    test('요청자 없는 프리셋 → detail 없어도 true', () {
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.coveringForSomeone, ''),
        isTrue,
      );
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.storeNeedsHelp, ''),
        isTrue,
      );
    });

    test('"불려서 왔다" + 요청자 미지정 → false (이 항목의 존재 이유가 대상자다)', () {
      expect(
        canSubmitEarlyClockIn(EarlyClockInReason.askedToComeEarly, ''),
        isFalse,
      );
      // 직접 입력을 골라놓고 이름을 안 적은 경우도 같다.
      expect(
        canSubmitEarlyClockIn(
          EarlyClockInReason.askedToComeEarly,
          '',
          requester: const EarlyRequester(name: '   '),
        ),
        isFalse,
      );
    });

    test('"불려서 왔다" + 요청자 지정 → true (목록/직접 입력 둘 다)', () {
      expect(
        canSubmitEarlyClockIn(
          EarlyClockInReason.askedToComeEarly,
          '',
          requester: const EarlyRequester(name: 'John Kim', userId: 'u-1'),
        ),
        isTrue,
      );
      expect(
        canSubmitEarlyClockIn(
          EarlyClockInReason.askedToComeEarly,
          '',
          requester: const EarlyRequester(name: 'Sam from HQ'),
        ),
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
        earlyClockInReasonToSubmit(EarlyClockInReason.coveringForSomeone, ''),
        'Covering for someone',
      );
    });

    test('"불려서 왔다" → 괄호 안에 이름 (계약 §2.2, 항상 영어)', () {
      expect(
        earlyClockInReasonToSubmit(
          EarlyClockInReason.askedToComeEarly,
          '',
          requester: const EarlyRequester(name: 'John Kim', userId: 'u-1'),
        ),
        'Asked to come in early (John Kim)',
      );
      expect(
        earlyClockInReasonToSubmit(
          EarlyClockInReason.askedToComeEarly,
          '',
          requester: const EarlyRequester(name: '  Sam from HQ  '),
        ),
        'Asked to come in early (Sam from HQ)',
      );
    });

    test('D10 — 다른 프리셋엔 대상자를 붙이지 않는다', () {
      expect(
        earlyClockInReasonToSubmit(
          EarlyClockInReason.coveringForSomeone,
          '',
          requester: const EarlyRequester(name: 'John Kim', userId: 'u-1'),
        ),
        'Covering for someone',
      );
    });

    test('other → 사용자가 적은 문장 (trim)', () {
      expect(
        earlyClockInReasonToSubmit(EarlyClockInReason.other, '  Bus early  '),
        'Bus early',
      );
    });
  });

  group('earlyClockInRequestedBy', () {
    test('목록에서 고른 사람만 id 를 보낸다', () {
      expect(
        earlyClockInRequestedBy(
          EarlyClockInReason.askedToComeEarly,
          requester: const EarlyRequester(name: 'John Kim', userId: 'u-1'),
        ),
        'u-1',
      );
    });

    test('"직접 입력" 은 id 를 보내지 않는다 (명단 밖 사람이라 id 가 없다, D9)', () {
      expect(
        earlyClockInRequestedBy(
          EarlyClockInReason.askedToComeEarly,
          requester: const EarlyRequester(name: 'Sam from HQ'),
        ),
        isNull,
      );
    });

    test('다른 프리셋은 id 를 보내지 않는다 (서버가 조용히 무시할 값을 안 만든다)', () {
      expect(
        earlyClockInRequestedBy(
          EarlyClockInReason.coveringForSomeone,
          requester: const EarlyRequester(name: 'John Kim', userId: 'u-1'),
        ),
        isNull,
      );
      expect(earlyClockInRequestedBy(EarlyClockInReason.other), isNull);
    });
  });

  group('EarlyRequester.withoutId', () {
    test('이름은 남기고 id 만 뗀다 (invalid_reason_user 재시도)', () {
      const r = EarlyRequester(name: 'John Kim', userId: 'u-1');
      expect(r.withoutId.name, 'John Kim');
      expect(r.withoutId.userId, isNull);
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
