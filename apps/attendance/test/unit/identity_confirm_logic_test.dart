/// identity_confirm_logic unit tests — Phase 5 Recovery C.

import 'package:attendance/utils/identity_confirm_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCloseOnly', () {
    test('null → true (no shift)', () {
      expect(isCloseOnly(null), true);
    });

    test('clocked_out → true', () {
      expect(isCloseOnly('clocked_out'), true);
    });

    test('working / on_break → false (Yes + Close)', () {
      expect(isCloseOnly('working'), false);
      expect(isCloseOnly('on_break'), false);
    });

    test('upcoming / soon / late / no_show → false', () {
      for (final s in ['upcoming', 'soon', 'late', 'no_show']) {
        expect(isCloseOnly(s), false, reason: s);
      }
    });

    test('알 수 없는 status → false (안전한 default — Yes 노출)', () {
      expect(isCloseOnly('something_else'), false);
    });
  });

  group('labelForStatus', () {
    test('working → "Currently working"', () {
      expect(labelForStatus('working'), 'Currently working');
    });

    test('on_break → "On break"', () {
      expect(labelForStatus('on_break'), 'On break');
    });

    test('upcoming → "Shift upcoming"', () {
      expect(labelForStatus('upcoming'), 'Shift upcoming');
    });

    test('soon → "Shift starting soon"', () {
      expect(labelForStatus('soon'), 'Shift starting soon');
    });

    test('late → "Running late"', () {
      expect(labelForStatus('late'), 'Running late');
    });

    test('no_show → "No-show"', () {
      expect(labelForStatus('no_show'), 'No-show');
    });

    test('clocked_out → "Shift completed"', () {
      expect(labelForStatus('clocked_out'), 'Shift completed');
    });

    test('unknown → input 그대로', () {
      expect(labelForStatus('foo'), 'foo');
    });
  });

  group('initialsOf', () {
    test('빈 문자열 → "?"', () {
      expect(initialsOf(''), '?');
    });

    test('한 단어 → 첫 글자 대문자', () {
      expect(initialsOf('Marcus'), 'M');
      expect(initialsOf('marcus'), 'M');
    });

    test('두 단어 → 각 첫 글자', () {
      expect(initialsOf('Marcus Lee'), 'ML');
      expect(initialsOf('sarah kim'), 'SK');
    });

    test('세 단어 이상 → 앞 두 단어만', () {
      expect(initialsOf('Marcus Lee Junior'), 'ML');
      expect(initialsOf('Jose Maria del Pilar'), 'JM');
    });

    test('연속 공백 정상 split', () {
      expect(initialsOf('Marcus   Lee'), 'ML');
    });

    test('앞뒤 공백 trim', () {
      expect(initialsOf('  Marcus Lee  '), 'ML');
    });
  });
}
