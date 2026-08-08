/// APK 인앱 다운로드 + PackageInstaller intent 발사.
///
/// 흐름:
///   1. server 가 응답 헤더 (X-App-Download-Url) 또는 GET /app-version 으로
///      pre-signed URL 전달
///   2. AppUpdateNotifier(전역 상태) 가 [downloadApk] 를 호출 — 화면 수명과 무관
///   3. Dio 가 APK 를 app cache dir 에 받는 동안 진행률 callback
///   4. ready 상태에서 사용자가 설치를 누르면 open_filex 가 ACTION_VIEW intent
///      (mime: vnd.android.package-archive) 발사 → OS PackageInstaller 노출
///
/// 파일 규약:
///   - 완성본: htma_update_<version 정제>.apk (version 의 '+' 는 '_' 로 치환)
///   - 다운로드 중: 같은 이름 + .part — 성공 시에만 rename 으로 승격되므로
///     미완성 파일이 완성본으로 오인될 수 없다
///   - 시작 전 다른 버전의 잔여 htma_update_* 파일은 정리 (캐시 누적 방지)
///
/// 권한:
///   - REQUEST_INSTALL_PACKAGES (AndroidManifest)
///   - FileProvider authorities="${applicationId}.fileprovider" (AndroidManifest +
///     res/xml/provider_paths.xml)
///
/// 실패 시나리오:
///   - 네트워크 실패 → DioException 그대로 throw
///   - 디스크 부족 → IOException
///   - 사용자가 Unknown sources 비활성화 → open_filex 는 done 으로 떨어지지만
///     OS 가 즉시 "Settings" 안내 화면을 띄움. 별도 처리 불필요.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';

typedef DownloadProgress = void Function(double progress);

class AppInstaller {
  AppInstaller._();

  /// [version] 의 완성본 APK 파일명. '+' 는 파일명에 부적합해 '_' 로 치환.
  static String apkFileName(String version) =>
      'htma_update_${version.replaceAll('+', '_')}.apk';

  /// [version] 의 완성본 APK 가 캐시에 남아 있으면 경로를, 없으면 null 반환.
  ///
  /// 완성본은 다운로드 성공 시 rename 으로만 생기므로 (.part 승격),
  /// 존재 = 온전한 파일로 간주해도 된다.
  static Future<String?> existingApkPath(String version) async {
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/${apkFileName(version)}');
    if (await file.exists()) return file.path;
    return null;
  }

  /// APK 를 app cache dir 로 다운로드하고 로컬 파일 경로를 반환한다.
  ///
  /// 설치와 분리돼 있다 — 상태 전이(ready → 설치 확인 → 키오스크 해제 →
  /// [installApk]) 는 AppUpdateNotifier 가 오케스트레이션한다.
  ///
  /// [url] : 다운로드 가능한 직접 URL (서버 발급 pre-signed URL).
  /// [version] : 대상 버전 — 파일명에 박아 완성본 재사용 판단에 쓴다.
  /// [onProgress] : 0.0 ~ 1.0 진행률 콜백. content-length 헤더가 없으면 발사 안 됨.
  /// throws : DioException / IOException
  static Future<String> downloadApk(
    String url, {
    required String version,
    DownloadProgress? onProgress,
  }) async {
    final dir = await getApplicationCacheDirectory();
    final target = File('${dir.path}/${apkFileName(version)}');
    // 다른 버전의 잔여 파일(구 완성본/.part/레거시 htma_update.apk) 정리 —
    // 버전이 파일명에 들어가면서 캐시가 무한히 쌓이지 않게 시작 전에 청소한다.
    await _cleanupStaleFiles(dir, keepName: apkFileName(version));

    final part = File('${target.path}.part');
    if (await part.exists()) {
      // 이전 시도의 미완성 파일 — 이어받기는 지원하지 않으므로 새로 받는다.
      await part.delete();
    }

    final dio = Dio();
    await dio.download(
      _rewriteHostForClient(url),
      part.path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
      options: Options(
        // Pre-signed URL 은 추가 Authorization 헤더가 붙으면 400 나는 경우가 있음.
        // attendance device 의 Dio 와는 별개 인스턴스라 interceptor 영향 없음.
        receiveTimeout: const Duration(minutes: 3),
      ),
    );

    // 성공 시에만 완성본 이름으로 승격 — 실패하면 .part 로 남아 재사용되지 않는다.
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    return target.path;
  }

  /// 다운로드된 APK 로 OS PackageInstaller 를 띄운다 (ACTION_VIEW intent).
  ///
  /// 주의: 키오스크 lock-task 가 켜져 있으면 설치 관리자가 포그라운드로 못 오므로,
  /// 호출 전에 반드시 lock-task 를 해제해야 한다 (AppUpdateNotifier.install 이 처리).
  /// throws : [AppInstallerException]
  static Future<void> installApk(String apkPath) async {
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw AppInstallerException(
        'OS install intent failed: ${result.type.name} — ${result.message}',
      );
    }
  }

  /// [keepName] 을 제외한 htma_update* 파일 전부 삭제. 실패는 무시 —
  /// 청소가 안 됐다고 다운로드를 막을 이유는 없다.
  static Future<void> _cleanupStaleFiles(
    Directory dir, {
    required String keepName,
  }) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('htma_update')) continue;
        if (name == keepName) continue;
        try {
          await entity.delete();
        } catch (_) {
          // 개별 삭제 실패 무시
        }
      }
    } catch (_) {
      // 목록 조회 실패 무시
    }
  }
}

/// 로컬 dev/worktree 환경에서 서버가 localhost URL 을 반환할 때 Android
/// emulator (10.0.2.2) 등에서 닿지 않는 문제를 회피한다. API_BASE_URL 의
/// host 가 localhost 가 아니면 download URL 의 loopback host 를 같은 값으로
/// 치환. S3 같은 prod URL 은 그대로 통과.
String _rewriteHostForClient(String downloadUrl) {
  final dl = Uri.parse(downloadUrl);
  if (dl.host != 'localhost' && dl.host != '127.0.0.1') return downloadUrl;
  final api = Uri.parse(AppConstants.apiBaseUrl);
  if (api.host == 'localhost' || api.host == '127.0.0.1') return downloadUrl;
  return dl.replace(host: api.host, port: api.port).toString();
}

class AppInstallerException implements Exception {
  final String message;
  const AppInstallerException(this.message);

  @override
  String toString() => 'AppInstallerException: $message';
}
