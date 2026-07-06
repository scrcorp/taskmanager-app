import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/widgets/time_watermark.dart';

void main() {
  group('WatermarkedPhoto', () {
    testWidgets('time 이 있으면 사진 아래 TimeWatermark 캡션을 그린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WatermarkedPhoto(
            time: DateTime(2026, 3, 5, 14, 30),
            child: const SizedBox(width: 160, height: 160),
          ),
        ),
      );
      expect(find.byType(TimeWatermark), findsOneWidget);
      // 시계 아이콘 표시
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('time 이 null 이어도 캡션 UI 는 그리고 "No time" 을 표시한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const WatermarkedPhoto(
            time: null,
            child: SizedBox(width: 160, height: 160),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 무음 실패 금지 — 시각이 없어도 워터마크 UI 는 뜨고, 시각 대신 "No time".
      expect(find.byType(TimeWatermark), findsOneWidget);
      expect(find.text('No time'), findsOneWidget);
    });
  });

  group('TimeWatermark', () {
    testWidgets('포맷된 시각 라벨 + 타임존을 표시한다 ("MMM d, h:mm a <tz>")', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TimeWatermark(time: DateTime(2026, 3, 5, 14, 30))),
      );
      // 타임존 약어는 실행 환경마다 다르므로 날짜·시간 부분만 검증.
      expect(find.textContaining('Mar 5, 2:30 PM'), findsOneWidget);
    });
  });
}
