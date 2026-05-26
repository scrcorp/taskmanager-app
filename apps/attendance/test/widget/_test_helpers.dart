/// 공용 widget test helpers — l10n delegates 자동 wrap.

import 'package:attendance/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 PIN-first 화면 widget test 가 사용. AppL10n.of(context) 가 정상 작동하도록
/// localizationsDelegates + supportedLocales 자동 주입.
Widget wrapForTest(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    // 큰 widget (PinNumpad/dialog) 가 default 800x600 surface 보다 클 수 있어 scroll 로 감쌈.
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// 태블릿 viewport (1200x1200) 강제 — 큰 키패드/대화상자 widget test 용.
/// addTearDown 으로 자동 원복.
Future<void> useTabletSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
