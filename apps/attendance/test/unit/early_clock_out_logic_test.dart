/// early_clock_out_logic unit tests — Phase 5 Recovery E.

import 'package:attendance/models/early_clock_out_reason.dart';
import 'package:attendance/utils/early_clock_out_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canSubmitEarlyClockOut', () {
    test('reason null → false', () {
      expect(canSubmitEarlyClockOut(null, ''), false);
      expect(canSubmitEarlyClockOut(null, 'Some detail'), false);
    });

    test('non-other reason → detail 상관없이 true', () {
      for (final r in [
        EarlyClockOutReason.feelingUnwell,
        EarlyClockOutReason.familyEmergency,
        EarlyClockOutReason.managerApproved,
        EarlyClockOutReason.personal,
      ]) {
        expect(canSubmitEarlyClockOut(r, ''), true, reason: r.name);
        expect(canSubmitEarlyClockOut(r, 'whatever'), true, reason: r.name);
      }
    });

    test('other + 빈 detail → false', () {
      expect(canSubmitEarlyClockOut(EarlyClockOutReason.other, ''), false);
    });

    test('other + 공백만 → false', () {
      expect(canSubmitEarlyClockOut(EarlyClockOutReason.other, '   '), false);
      expect(canSubmitEarlyClockOut(EarlyClockOutReason.other, '\n\t '), false);
    });

    test('other + 실제 내용 → true', () {
      expect(canSubmitEarlyClockOut(EarlyClockOutReason.other, 'Doctor appointment'), true);
    });

    test('other + 앞뒤 공백 포함 내용 → true', () {
      expect(canSubmitEarlyClockOut(EarlyClockOutReason.other, '  Pick up child  '), true);
    });
  });

  group('formatRemainingMinutes', () {
    test('0 → "0m"', () {
      expect(formatRemainingMinutes(0), '0m');
    });

    test('30 → "30m"', () {
      expect(formatRemainingMinutes(30), '30m');
    });

    test('59 → "59m"', () {
      expect(formatRemainingMinutes(59), '59m');
    });

    test('60 → "1h 0m"', () {
      expect(formatRemainingMinutes(60), '1h 0m');
    });

    test('90 → "1h 30m"', () {
      expect(formatRemainingMinutes(90), '1h 30m');
    });

    test('240 → "4h 0m"', () {
      expect(formatRemainingMinutes(240), '4h 0m');
    });

    test('245 → "4h 5m"', () {
      expect(formatRemainingMinutes(245), '4h 5m');
    });

    test('음수 → "0m" (방어)', () {
      expect(formatRemainingMinutes(-5), '0m');
    });
  });

  group('detailToSubmit', () {
    test('other 외 → null', () {
      for (final r in [
        EarlyClockOutReason.feelingUnwell,
        EarlyClockOutReason.familyEmergency,
        EarlyClockOutReason.managerApproved,
        EarlyClockOutReason.personal,
      ]) {
        expect(detailToSubmit(r, 'anything'), isNull, reason: r.name);
      }
    });

    test('other + 내용 → trimmed', () {
      expect(detailToSubmit(EarlyClockOutReason.other, '  Doctor appointment  '), 'Doctor appointment');
    });

    test('other + 빈 문자열 → ""', () {
      expect(detailToSubmit(EarlyClockOutReason.other, ''), '');
    });
  });
}
