import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/widgets/photo_viewer.dart';
import 'package:app/widgets/time_watermark.dart';

void main() {
  // 프로덕션(체크리스트 사진 썸네일)과 동일한 배선을 재현한다:
  // 썸네일 i 를 탭하면 openPhotoViewer(초기 인덱스 = 탭한 위치)로 풀스크린 확대.
  Widget thumbnailHarness({
    required List<String> urls,
    required List<DateTime?> times,
  }) {
    return MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Row(
            children: [
              for (var i = 0; i < urls.length; i++)
                GestureDetector(
                  key: ValueKey('thumb_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openPhotoViewer(
                    context,
                    urls: urls,
                    times: times,
                    initialIndex: i,
                  ),
                  child: const SizedBox(width: 40, height: 40),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 빈 urls 가드 검증용: 버튼 탭 시 빈 리스트로 openPhotoViewer 호출.
  Widget emptyGuardHarness() {
    return MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const ValueKey('open_empty'),
              onPressed: () => openPhotoViewer(context, urls: const []),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('openPhotoViewer (썸네일 탭 → 풀스크린 확대)', () {
    final urls = <String>[
      'https://example.com/a.webp',
      'https://example.com/b.webp',
      'https://example.com/c.webp',
    ];
    final times = <DateTime?>[
      DateTime(2026, 3, 5, 14, 30),
      null, // 찍힌 시각 없음 → "No time"
      DateTime(2026, 3, 7, 9, 0),
    ];

    testWidgets('썸네일 탭 → PageView + 핀치줌(InteractiveViewer) 뷰어가 열린다', (
      tester,
    ) async {
      await tester.pumpWidget(thumbnailHarness(urls: urls, times: times));
      // 열기 전엔 뷰어 없음
      expect(find.byType(PageView), findsNothing);

      await tester.tap(find.byKey(const ValueKey('thumb_0')));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      // 탭한 사진(index 0)의 찍힌 시각 캡션
      expect(find.byType(TimeWatermark), findsOneWidget);
      expect(find.textContaining('Mar 5, 2026, 2:30 PM'), findsOneWidget);
    });

    testWidgets('탭한 인덱스로 열린다 — 세 번째 썸네일 → "3 / 3" + 해당 촬영시각', (tester) async {
      await tester.pumpWidget(thumbnailHarness(urls: urls, times: times));

      await tester.tap(find.byKey(const ValueKey('thumb_2')));
      await tester.pumpAndSettle();

      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.textContaining('Mar 7, 2026, 9:00 AM'), findsOneWidget);
    });

    testWidgets('찍힌 시각 없는 사진은 "No time" 캡션 (무음 실패 금지)', (tester) async {
      await tester.pumpWidget(thumbnailHarness(urls: urls, times: times));

      await tester.tap(find.byKey(const ValueKey('thumb_1')));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('No time'), findsOneWidget);
    });

    testWidgets('urls 가 비면 뷰어를 열지 않는다 (가드)', (tester) async {
      await tester.pumpWidget(emptyGuardHarness());

      await tester.tap(find.byKey(const ValueKey('open_empty')));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
    });
  });
}
