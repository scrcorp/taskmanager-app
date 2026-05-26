/// pin_input_logic unit tests — Phase 5 Recovery B.

import 'package:attendance/utils/pin_input_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('maskedPin', () {
    test('빈 pin → ""', () {
      expect(maskedPin('', false), '');
      expect(maskedPin('', true), '');
    });

    test('reveal=false → 자릿수만큼 ●', () {
      expect(maskedPin('1', false), '•');
      expect(maskedPin('12', false), '••');
      expect(maskedPin('123456', false), '••••••');
    });

    test('reveal=true → 원본 pin 그대로', () {
      expect(maskedPin('1', true), '1');
      expect(maskedPin('1234', true), '1234');
      expect(maskedPin('987654', true), '987654');
    });
  });

  group('canSubmitPin', () {
    test('빈 pin → false', () {
      expect(canSubmitPin('', 4), false);
    });

    test('minLength 미만 → false', () {
      expect(canSubmitPin('1', 4), false);
      expect(canSubmitPin('12', 4), false);
      expect(canSubmitPin('123', 4), false);
    });

    test('minLength 정확히 도달 → true', () {
      expect(canSubmitPin('1234', 4), true);
    });

    test('minLength 초과 → true', () {
      expect(canSubmitPin('12345', 4), true);
      expect(canSubmitPin('123456', 4), true);
    });

    test('enabled=false 면 어떤 길이여도 false', () {
      expect(canSubmitPin('1234', 4, enabled: false), false);
      expect(canSubmitPin('123456', 4, enabled: false), false);
    });
  });

  group('appendDigit', () {
    test('빈 pin 에 추가 → 한 자리', () {
      expect(appendDigit('', '1', 6), '1');
    });

    test('기존 pin 뒤에 누적', () {
      expect(appendDigit('1', '2', 6), '12');
      expect(appendDigit('12', '3', 6), '123');
    });

    test('maxLength 도달 시 무시 (기존 그대로)', () {
      expect(appendDigit('123456', '7', 6), '123456');
    });

    test('maxLength 직전까지는 추가', () {
      expect(appendDigit('12345', '6', 6), '123456');
    });
  });

  group('backspaceDigit', () {
    test('빈 pin → 빈 그대로', () {
      expect(backspaceDigit(''), '');
    });

    test('한 자리 → 빈 문자열', () {
      expect(backspaceDigit('1'), '');
    });

    test('마지막 한 글자 제거', () {
      expect(backspaceDigit('123'), '12');
      expect(backspaceDigit('123456'), '12345');
    });
  });
}
