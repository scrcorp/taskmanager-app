/// AppUpdateOverlay(전역 업데이트 배너) widget test.
///
/// MaterialApp.builder 로 끼워지는 배너가 phase 별로 올바르게 렌더되는지 고정.
///   - idle: 아무것도 안 보임
///   - downloading: 진행바 + % (+ 터치는 아래 라우트로 통과)
///   - ready: "Update Downloaded" + Install 버튼 — 탭하면 intent 발사 동안
///     installing, 발사 후 ready 복귀 (OS 취소 복구 경로)
///   - installing: "Launching installer…"
///   - error: 원인+다음 행동 문구 + Retry + 닫기(X)
///   - 배너는 AppBar toolbar 밴드 아래에 떠서 뒤로가기를 가로막지 않는다
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/l10n/app_localizations.dart';
import 'package:attendance/providers/app_update_provider.dart';
import 'package:attendance/utils/app_installer.dart';
import 'package:attendance/widgets/app_update_banner.dart';

/// 원하는 상태를 미리 꽂아 렌더를 검증하는 대역. 주입 fn 은 전부 무해한 성공.
class _StubUpdateNotifier extends AppUpdateNotifier {
  _StubUpdateNotifier(AppUpdateState initial, {InstallApkFn? install})
      : super(
          download: (url,
                  {required String version, DownloadProgress? onProgress}) async =>
              '/cache/htma_update_stub.apk',
          install: install ?? (path) async {},
          existingApkPath: (version) async => null,
        ) {
    state = initial;
  }
}

/// install() 은 KioskLock(MethodChannel) 을 지나간다. testWidgets 의 FakeAsync
/// 안에서는 실제 엔진의 채널 응답이 도착하지 못해 install() 이 isLocked() 에서
/// 영원히 멈추므로, 채널을 mock 으로 즉시 응답시켜야 상태 전이를 관찰할 수 있다.
void _mockKioskChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.tigersplus.app/kiosk'),
    (call) async => false,
  );
}

Widget _wrap(AppUpdateNotifier notifier, {Widget? home}) {
  return ProviderScope(
    overrides: [appUpdateProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      // 실제 앱(main.dart)과 동일한 배선.
      builder: (context, child) => AppUpdateOverlay(child: child),
      home: home ?? const Scaffold(body: Center(child: Text('under'))),
    ),
  );
}

void main() {
  testWidgets('idle 이면 배너가 렌더되지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_StubUpdateNotifier(const AppUpdateState())));
    await tester.pumpAndSettle();

    expect(find.text('under'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Update Downloaded'), findsNothing);
  });

  testWidgets('downloading: 진행바 + % 표시', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(
            phase: AppUpdatePhase.downloading,
            progress: 0.42,
            targetVersion: '1.0.12+33',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Downloading'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('ready: Install 탭 → intent 발사 동안 installing, 발사 후 ready 복귀',
      (tester) async {
    _mockKioskChannel(tester);
    // intent 발사(install fn)를 게이트로 잡아 과도 상태를 관찰한다.
    final gate = Completer<void>();
    final notifier = _StubUpdateNotifier(
      const AppUpdateState(
        phase: AppUpdatePhase.ready,
        apkPath: '/cache/htma_update_1_0_12_33.apk',
      ),
      install: (path) => gate.future,
    );
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    expect(find.text('Update Downloaded'), findsOneWidget);
    expect(find.text('Install Now'), findsOneWidget);

    // Install 탭 → installing (intent 발사 중).
    // installing 스피너는 무한 애니메이션이라 pumpAndSettle 을 쓰면 안 된다.
    await tester.tap(find.text('Install Now'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Launching installer…'), findsOneWidget);

    // intent 발사 완료 — OS 다이얼로그에서 취소하고 돌아온 경우에 대비해
    // ready 로 복귀, Install 버튼이 다시 보인다 (고착 금지).
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Launching installer…'), findsNothing);
    expect(find.text('Update Downloaded'), findsOneWidget);
    expect(find.text('Install Now'), findsOneWidget);
  });

  testWidgets('installing: Launching installer… 표시', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(phase: AppUpdatePhase.installing),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Launching installer…'), findsOneWidget);
  });

  testWidgets('error: 원인별 문구 + Retry + 닫기(X)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(
            phase: AppUpdatePhase.error,
            errorKind: AppUpdateErrorKind.network,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Download failed due to a network problem. '
        'Check the connection and tap Retry.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('error 배너의 X 를 누르면 배너가 사라진다 (idle 복귀)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(
            phase: AppUpdatePhase.error,
            errorKind: AppUpdateErrorKind.disk,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'Not enough storage to download the update. '
        'Free up space and retry.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('under'), findsOneWidget);
  });

  testWidgets('installer 에러 문구는 다음 행동(키오스크 해제) 을 안내한다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(
            phase: AppUpdatePhase.error,
            errorKind: AppUpdateErrorKind.installer,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Could not open the installer. Unlock kiosk mode and retry.'),
      findsOneWidget,
    );
  });

  testWidgets('downloading: 배너가 AppBar 뒤로가기와 아래 화면 터치를 막지 않는다',
      (tester) async {
    var backTapped = false;
    var underTapped = false;
    await tester.pumpWidget(
      _wrap(
        _StubUpdateNotifier(
          const AppUpdateState(
            phase: AppUpdatePhase.downloading,
            progress: 0.5,
            targetVersion: '1.0.12+33',
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => backTapped = true,
            ),
            title: const Text('Settings'),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: TextButton(
                onPressed: () => underTapped = true,
                child: const Text('UNDER-TAP'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 배너는 toolbar 밴드 아래에 있어 뒤로가기를 가리지 않는다.
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue,
        reason: '다운로드 중에도 AppBar 뒤로가기가 눌려야 한다');

    // 배너 자체(진행바 위치)를 눌러도 터치가 아래 라우트로 통과한다.
    await tester.tapAt(tester.getCenter(find.byType(LinearProgressIndicator)));
    await tester.pump();
    expect(underTapped, isTrue,
        reason: 'downloading 배너엔 누를 것이 없다 — 터치는 통과해야 한다');
  });

  testWidgets('ready: 배너 버튼은 눌리면서 AppBar 뒤로가기도 눌린다', (tester) async {
    _mockKioskChannel(tester);
    var backTapped = false;
    final notifier = _StubUpdateNotifier(
      const AppUpdateState(
        phase: AppUpdatePhase.ready,
        apkPath: '/cache/htma_update_1_0_12_33.apk',
      ),
    );
    await tester.pumpWidget(
      _wrap(
        notifier,
        home: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => backTapped = true,
            ),
            title: const Text('Settings'),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    // 배너는 toolbar 밴드 아래에 있어 인터랙티브 상태에서도 뒤로가기가 눌린다.
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue,
        reason: 'ready 배너가 AppBar 뒤로가기를 가리면 안 된다');

    // 배너 자신의 Install 버튼도 여전히 탭 가능해야 한다.
    // (no-op install 은 intent 발사 후 즉시 ready 복귀 → 애니메이션이 멈춰
    // pumpAndSettle 사용 가능)
    await tester.tap(find.text('Install Now'));
    await tester.pumpAndSettle();
    expect(find.text('Launching installer…'), findsNothing);
    expect(find.text('Update Downloaded'), findsOneWidget);
  });
}
