// Smoke test: does WarningPdfView render without throwing a layout/runtime error?
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/warning.dart';
import 'package:app/services/api_client.dart' show dioProvider;
import 'package:app/screens/warnings/warning_pdf_view.dart';

void main() {
  testWidgets('WarningPdfView renders without throwing', (tester) async {
    final w = Warning(
      id: 'w1',
      refNo: 'W-00001',
      status: 'active',
      title: 'Timekeeping warning',
      categories: const ['tardiness', 'damaged_equipment'],
      categoryLabels: const {
        'tardiness': 'Tardiness',
        'damaged_equipment': 'Damaged equipment',
      },
      details: 'The employee was late multiple times. ' * 10,
      correctiveAction: 'Be on time going forward.',
      subjectName: 'Donnie Tran',
      employeeNo: 'STF-001',
      issuedByName: 'Kevin Park',
      storeName: 'M Korean BBQ',
      warningDate: DateTime(2026, 6, 1),
      ordinal: 1,
      employeeSignature: const SigInfo(
        signerName: 'Donnie Tran',
        method: 'drawn',
        signatureStrokes: SignatureStrokes(
          strokes: [
            [
              [0.1, 0.5],
              [0.5, 0.2],
              [0.9, 0.8],
            ],
          ],
          aspect: 2.6,
        ),
      ),
    );

    // Mock dio so AppHeader's initState network calls resolve (no real server),
    // isolating any REAL layout error from test-only network noise.
    final mockDio = Dio();
    mockDio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      h.resolve(Response(
        requestOptions: o,
        statusCode: 200,
        data: {'unsigned_count': 0, 'unread_count': 0, 'items': [], 'total': 0},
      ));
    }));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(mockDio)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: WarningPdfView(warning: w),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final ex = tester.takeException();
    expect(ex, isNull, reason: 'WarningPdfView threw during render: $ex');
  });
}
