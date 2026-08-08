/// AppUpdateNotifier unit test.
///
/// 계약: 다운로드/설치 상태는 화면(State) 이 아니라 앱 수명의 전역 notifier 가
/// 보유한다 (2026-08-07 이슈 1). 실제 Dio/파일시스템 대신 생성자 주입 fake 로
/// 상태 전이만 고정한다.
///   - 진행률 반영 → ready 전이
///   - 같은 버전 완성본 캐시 재사용 (재다운로드 없음)
///   - 예외 → errorKind 분류 (DioException=network / IOException=disk / 그 외=unknown)
///   - install: intent 발사 동안만 installing, 발사 후 ready 복귀 (OS 취소 복구)
///   - install 실패 → installer error
///   - retry / dismissError
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance/providers/app_update_provider.dart';
import 'package:attendance/utils/app_installer.dart';

void main() {
  // install() 이 KioskLock(MethodChannel) 을 지나간다 — 테스트 바인딩에선
  // MissingPluginException 을 KioskLock 이 삼키고 false 를 반환한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  AppUpdateNotifier makeNotifier({
    DownloadApkFn? download,
    InstallApkFn? install,
    ExistingApkPathFn? existingApkPath,
  }) {
    return AppUpdateNotifier(
      download: download ??
          (url, {required String version, DownloadProgress? onProgress}) async =>
              '/cache/htma_update_ok.apk',
      install: install ?? (path) async {},
      existingApkPath: existingApkPath ?? (version) async => null,
    );
  }

  group('startDownload', () {
    test('진행률이 상태에 반영되고 완료 시 ready + apkPath', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          onProgress?.call(0.25);
          onProgress?.call(0.8);
          return '/cache/htma_update_1_0_12_33.apk';
        },
      );
      final seenProgress = <double?>[];
      notifier.addListener((s) {
        if (s.phase == AppUpdatePhase.downloading) seenProgress.add(s.progress);
      });

      await notifier.startDownload('http://x/apk', '1.0.12+33');

      expect(notifier.state.phase, AppUpdatePhase.ready);
      expect(notifier.state.apkPath, '/cache/htma_update_1_0_12_33.apk');
      expect(notifier.state.progress, 1.0);
      expect(notifier.state.targetVersion, '1.0.12+33');
      expect(notifier.state.downloadUrl, 'http://x/apk');
      expect(seenProgress, containsAllInOrder([0.25, 0.8]));
    });

    test('같은 버전 완성본이 캐시에 있으면 재다운로드 없이 즉시 ready', () async {
      var downloadCalls = 0;
      final notifier = makeNotifier(
        existingApkPath: (version) async => '/cache/htma_update_1_0_12_33.apk',
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          downloadCalls += 1;
          return '/cache/should_not_happen.apk';
        },
      );

      await notifier.startDownload('http://x/apk', '1.0.12+33');

      expect(downloadCalls, 0, reason: '캐시 재사용이면 다운로드 함수가 불리면 안 된다');
      expect(notifier.state.phase, AppUpdatePhase.ready);
      expect(notifier.state.apkPath, '/cache/htma_update_1_0_12_33.apk');
    });

    test('이미 downloading 이면 재호출은 무시된다', () async {
      final gate = Completer<String>();
      var downloadCalls = 0;
      final notifier = makeNotifier(
        download: (url, {required String version, DownloadProgress? onProgress}) {
          downloadCalls += 1;
          return gate.future;
        },
      );

      final first = notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.downloading);

      // 진행 중 재호출 — 상태/대상 버전이 바뀌면 안 된다.
      await notifier.startDownload('http://x/other', '9.9.9');
      expect(notifier.state.targetVersion, '1.0.12+33');

      gate.complete('/cache/htma_update_1_0_12_33.apk');
      await first;
      expect(downloadCalls, 1);
      expect(notifier.state.phase, AppUpdatePhase.ready);
    });
  });

  group('에러 분류', () {
    test('DioException → network', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          throw DioException(requestOptions: RequestOptions(path: '/apk'));
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.error);
      expect(notifier.state.errorKind, AppUpdateErrorKind.network);
    });

    test('FileSystemException → disk', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          throw const FileSystemException('No space left on device');
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.error);
      expect(notifier.state.errorKind, AppUpdateErrorKind.disk);
    });

    test('DioException 이 IOException 을 감싼 경우 → disk', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/apk'),
            error: const FileSystemException('write failed'),
          );
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.errorKind, AppUpdateErrorKind.disk);
    });

    test('그 외 예외 → unknown', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          throw StateError('boom');
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.error);
      expect(notifier.state.errorKind, AppUpdateErrorKind.unknown);
    });
  });

  group('install', () {
    test('intent 발사 동안 installing, 발사 후 ready 복귀 (OS 취소 복구 경로)', () async {
      // OpenFilex.open 은 설치 완료가 아니라 intent 발사 시점에 반환한다.
      // 사용자가 OS 다이얼로그에서 취소하고 돌아와도 고착되지 않도록
      // installing 은 과도 상태여야 한다.
      final gate = Completer<void>();
      final notifier = makeNotifier(install: (path) => gate.future);
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.ready);

      final installing = notifier.install();
      expect(notifier.state.phase, AppUpdatePhase.installing);

      // intent 발사 중엔 중복 다운로드/설치가 막힌다.
      await notifier.startDownload('http://x/other', '9.9.9');
      expect(notifier.state.targetVersion, '1.0.12+33');

      gate.complete();
      await installing;
      expect(notifier.state.phase, AppUpdatePhase.ready,
          reason: '취소 후 복귀 시 Install 버튼이 다시 보여야 한다');
      expect(notifier.state.apkPath, '/cache/htma_update_ok.apk',
          reason: '완성본 캐시가 유지돼 재설치가 즉시 가능해야 한다');
    });

    test('OS 다이얼로그 취소 후 재설치 가능 — install 이 다시 불린다', () async {
      var installCalls = 0;
      final notifier = makeNotifier(
        install: (path) async {
          installCalls += 1;
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');

      await notifier.install();
      expect(notifier.state.phase, AppUpdatePhase.ready);

      await notifier.install();
      expect(installCalls, 2);
      expect(notifier.state.phase, AppUpdatePhase.ready);
    });

    test('설치 intent 실패 → errorKind=installer', () async {
      final notifier = makeNotifier(
        install: (path) async {
          throw const AppInstallerException('intent failed');
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');

      await notifier.install();
      expect(notifier.state.phase, AppUpdatePhase.error);
      expect(notifier.state.errorKind, AppUpdateErrorKind.installer);
    });

    test('ready 가 아니면 무시', () async {
      var installCalls = 0;
      final notifier = makeNotifier(
        install: (path) async {
          installCalls += 1;
        },
      );
      await notifier.install(); // idle 상태
      expect(installCalls, 0);
      expect(notifier.state.phase, AppUpdatePhase.idle);
    });
  });

  group('retry / dismissError', () {
    test('retry 는 저장된 url/version 으로 재다운로드한다', () async {
      var calls = 0;
      String? lastUrl;
      String? lastVersion;
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          calls += 1;
          lastUrl = url;
          lastVersion = version;
          if (calls == 1) {
            throw DioException(requestOptions: RequestOptions(path: '/apk'));
          }
          return '/cache/htma_update_1_0_12_33.apk';
        },
      );

      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.error);

      await notifier.retry();
      expect(calls, 2);
      expect(lastUrl, 'http://x/apk');
      expect(lastVersion, '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.ready);
      expect(notifier.state.apkPath, '/cache/htma_update_1_0_12_33.apk');
    });

    test('installer 에러 후 retry 는 캐시 완성본으로 즉시 ready', () async {
      var downloadCalls = 0;
      final notifier = makeNotifier(
        existingApkPath: (version) async => '/cache/htma_update_1_0_12_33.apk',
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          downloadCalls += 1;
          return '/cache/should_not_happen.apk';
        },
        install: (path) async {
          throw const AppInstallerException('intent failed');
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      await notifier.install();
      expect(notifier.state.phase, AppUpdatePhase.error);
      expect(notifier.state.errorKind, AppUpdateErrorKind.installer);

      await notifier.retry();
      expect(downloadCalls, 0, reason: '완성본이 살아 있으니 재다운로드 없이 ready');
      expect(notifier.state.phase, AppUpdatePhase.ready);
    });

    test('dismissError 는 error 에서만 idle 로 복귀', () async {
      final notifier = makeNotifier(
        download:
            (url, {required String version, DownloadProgress? onProgress}) async {
          throw DioException(requestOptions: RequestOptions(path: '/apk'));
        },
      );
      await notifier.startDownload('http://x/apk', '1.0.12+33');
      expect(notifier.state.phase, AppUpdatePhase.error);

      notifier.dismissError();
      expect(notifier.state.phase, AppUpdatePhase.idle);
      expect(notifier.state.errorKind, isNull);

      // idle 에선 no-op
      notifier.dismissError();
      expect(notifier.state.phase, AppUpdatePhase.idle);
    });
  });
}
