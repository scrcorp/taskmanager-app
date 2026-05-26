/// tip_entry_logic unit tests — Phase 5 Recovery F.

import 'package:attendance/utils/tip_entry_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmount', () {
    test('null → 0', () {
      expect(parseAmount(null), 0);
    });

    test('빈 문자열 → 0', () {
      expect(parseAmount(''), 0);
    });

    test('정수 문자열 → double', () {
      expect(parseAmount('60'), 60);
    });

    test('소수점 → double', () {
      expect(parseAmount('12.50'), 12.5);
    });

    test('invalid → 0', () {
      expect(parseAmount('abc'), 0);
      expect(parseAmount('12.3.4'), 0);
    });

    test('공백 trim 후 파싱', () {
      expect(parseAmount('  30  '), 30);
    });
  });

  group('computeDistSum', () {
    test('빈 list → 0', () {
      expect(computeDistSum([]), 0);
    });

    test('한 명 — 단일 amount', () {
      expect(computeDistSum(['25']), 25);
    });

    test('여러 명 합산', () {
      expect(computeDistSum(['10', '15.5', '4.5']), 30);
    });

    test('invalid amount → 0 으로 처리', () {
      expect(computeDistSum(['10', '', 'abc', '5']), 15);
    });
  });

  group('overDistributed', () {
    test('합 < cardTips → false', () {
      expect(overDistributed(20, 50), false);
    });

    test('합 == cardTips → false (tolerance 안)', () {
      expect(overDistributed(50, 50), false);
    });

    test('합 > cardTips (큰 차이) → true', () {
      expect(overDistributed(60, 50), true);
    });

    test('부동소수점 epsilon (0.0001 차이) → false', () {
      expect(overDistributed(50.0001, 50), false);
    });

    test('부동소수점 epsilon 초과 (0.01 차이) → true', () {
      expect(overDistributed(50.01, 50), true);
    });
  });

  group('canSubmitTip', () {
    test('card 비어있음 → false', () {
      expect(canSubmitTip(cardRaw: '', cashRaw: '5', distSum: 0), false);
    });

    test('cash 비어있음 → false', () {
      expect(canSubmitTip(cardRaw: '60', cashRaw: '', distSum: 0), false);
    });

    test('card/cash 공백만 → false', () {
      expect(canSubmitTip(cardRaw: '  ', cashRaw: '5', distSum: 0), false);
      expect(canSubmitTip(cardRaw: '60', cashRaw: '  ', distSum: 0), false);
    });

    test('card/cash 채워짐 + distSum 0 → true', () {
      expect(canSubmitTip(cardRaw: '60', cashRaw: '5', distSum: 0), true);
    });

    test('distSum <= card → true', () {
      expect(canSubmitTip(cardRaw: '60', cashRaw: '5', distSum: 30), true);
      expect(canSubmitTip(cardRaw: '60', cashRaw: '5', distSum: 60), true);
    });

    test('distSum > card → false', () {
      expect(canSubmitTip(cardRaw: '60', cashRaw: '5', distSum: 70), false);
    });

    test('card invalid (parse=0) + distSum>0 → false (over)', () {
      expect(canSubmitTip(cardRaw: 'abc', cashRaw: '5', distSum: 10), false);
    });
  });

  group('splitEvenlyAmount', () {
    test('receiver 0명 → "0.00"', () {
      expect(splitEvenlyAmount(60, 0), '0.00');
    });

    test('cardTips 0 → "0.00"', () {
      expect(splitEvenlyAmount(0, 3), '0.00');
    });

    test('cardTips 음수 → "0.00" (방어)', () {
      expect(splitEvenlyAmount(-10, 3), '0.00');
    });

    test('60 / 2 → "30.00"', () {
      expect(splitEvenlyAmount(60, 2), '30.00');
    });

    test('60 / 3 → "20.00"', () {
      expect(splitEvenlyAmount(60, 3), '20.00');
    });

    test('10 / 3 → "3.33" (소수점 2자리 fix)', () {
      expect(splitEvenlyAmount(10, 3), '3.33');
    });
  });
}
