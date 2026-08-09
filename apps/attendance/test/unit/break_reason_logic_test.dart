/// break_reason_logic unit tests.
///
/// 서버로 나가는 reason 문자열이 비지 않는 것이 핵심 — 빈 값이면 서버가 400 을
/// 주고 스태프는 휴식을 끝낼 수 없다.

import 'package:attendance/models/break_overrun_reason.dart';
import 'package:attendance/utils/break_reason_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canSubmitBreakReason', () {
    test('미선택 → false', () {
      expect(canSubmitBreakReason(null, ''), false);
      expect(canSubmitBreakReason(null, 'anything'), false);
    });

    test('프리셋 선택 → detail 없어도 true', () {
      for (final r in BreakOverrunReason.values) {
        if (r == BreakOverrunReason.other) continue;
        expect(canSubmitBreakReason(r, ''), true, reason: r.name);
      }
    });

    test('other + 공백만 → false', () {
      expect(canSubmitBreakReason(BreakOverrunReason.other, ''), false);
      expect(canSubmitBreakReason(BreakOverrunReason.other, '   '), false);
    });

    test('other + 내용 → true', () {
      expect(canSubmitBreakReason(BreakOverrunReason.other, 'Bus was late'), true);
    });
  });

  group('breakReasonToSubmit', () {
    test('프리셋 → 라벨 그대로 (콘솔에서 읽는 값)', () {
      expect(
        breakReasonToSubmit(BreakOverrunReason.forgotToEnd, ''),
        'Forgot to end break',
      );
      expect(
        breakReasonToSubmit(BreakOverrunReason.waitingForCoverage, 'ignored'),
        'Waiting for coverage',
      );
    });

    test('other → 자유 입력 trim', () {
      expect(
        breakReasonToSubmit(BreakOverrunReason.other, '  Bus was late  '),
        'Bus was late',
      );
    });

    test('제출 가능한 조합은 항상 비어있지 않은 문자열을 만든다', () {
      for (final r in BreakOverrunReason.values) {
        final detail = r == BreakOverrunReason.other ? 'something' : '';
        if (!canSubmitBreakReason(r, detail)) continue;
        expect(breakReasonToSubmit(r, detail).trim(), isNotEmpty, reason: r.name);
      }
    });
  });
}
