// Wet-sign(실물 서명 PDF) 분기 테스트.
//
// 다루는 것:
//  - Warning 모델의 wet 필드 파싱 + isWet/isSigned 파생.
//  - WarningStatusPill 의 3상태(digital signed / digital unsigned / wet 미업로드 / wet 업로드).
//  - 미서명 카운트(배지/독촉)가 wet 경고를 제외하는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/warning.dart';
import 'package:app/providers/warnings_provider.dart';
import 'package:app/screens/warnings/warning_status_pill.dart';

Warning _wet({required bool uploaded}) => Warning.fromJson({
      'id': 'w-wet',
      'ref_no': 'W-00010',
      'status': 'active',
      'title': 'Attendance',
      'signature_method': 'wet',
      'store_code': 'IFO',
      'signed_pdf_present': uploaded,
      'wet_signed_on': uploaded ? '2026-06-10' : null,
      'wet_uploaded_at': uploaded ? '2026-06-10T12:00:00' : null,
      'employee_signed': uploaded,
      'manager_signed': uploaded,
    });

Warning _digital({required bool signed}) => Warning.fromJson({
      'id': 'w-dig',
      'ref_no': 'W-00011',
      'status': 'active',
      'title': 'Tardiness',
      'signature_method': 'digital',
      'employee_signed': signed,
      'signatures': signed
          ? {
              'employee': {'signer_name': 'A', 'signed_at': '2026-06-09T10:00:00'},
            }
          : {},
    });

Future<void> _pumpPill(WidgetTester tester, Warning w) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: WarningStatusPill(warning: w)),
    ),
  );
  await tester.pump();
}

void main() {
  group('Warning model — wet fields', () {
    test('parses wet method and derived flags', () {
      final w = _wet(uploaded: true);
      expect(w.isWet, true);
      expect(w.signatureMethod, 'wet');
      expect(w.storeCode, 'IFO');
      expect(w.signedPdfPresent, true);
      expect(w.wetSignedOn, DateTime(2026, 6, 10));
      expect(w.wetUploadedAt, isNotNull);
      expect(w.employeeSigned, true);
      expect(w.managerSigned, true);
      // wet + 업로드 = 서명 완료.
      expect(w.isSigned, true);
    });

    test('wet not uploaded → not signed', () {
      final w = _wet(uploaded: false);
      expect(w.isWet, true);
      expect(w.signedPdfPresent, false);
      expect(w.isSigned, false);
      expect(w.wetSignedOn, isNull);
    });

    test('defaults to digital when signature_method absent', () {
      final w = Warning.fromJson({
        'id': 'x',
        'ref_no': 'W-1',
        'status': 'active',
        'title': 't',
      });
      expect(w.isWet, false);
      expect(w.signatureMethod, 'digital');
      expect(w.signedPdfPresent, false);
    });

    test('digital signed via employee_signed or signature row', () {
      expect(_digital(signed: true).isSigned, true);
      expect(_digital(signed: false).isSigned, false);
    });
  });

  group('WarningStatusPill', () {
    testWidgets('digital unsigned → "Signature required"', (tester) async {
      await _pumpPill(tester, _digital(signed: false));
      expect(find.text('Signature required'), findsOneWidget);
    });

    testWidgets('digital signed → "Signed"', (tester) async {
      await _pumpPill(tester, _digital(signed: true));
      expect(find.text('Signed'), findsOneWidget);
    });

    testWidgets('wet not uploaded → "Sign in person"', (tester) async {
      await _pumpPill(tester, _wet(uploaded: false));
      expect(find.text('Sign in person'), findsOneWidget);
    });

    testWidgets('wet uploaded → "Signed"', (tester) async {
      await _pumpPill(tester, _wet(uploaded: true));
      expect(find.text('Signed'), findsOneWidget);
    });
  });

  group('needsSignature (badge/nudge filter)', () {
    test('digital unsigned counts, signed does not', () {
      expect(WarningsNotifier.needsSignature(_digital(signed: false)), true);
      expect(WarningsNotifier.needsSignature(_digital(signed: true)), false);
    });

    test('wet warnings never count (uploaded or not)', () {
      expect(WarningsNotifier.needsSignature(_wet(uploaded: false)), false);
      expect(WarningsNotifier.needsSignature(_wet(uploaded: true)), false);
    });
  });
}
