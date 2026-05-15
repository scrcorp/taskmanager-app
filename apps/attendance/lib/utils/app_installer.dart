/// APK 인앱 다운로드 + PackageInstaller intent 발사.
///
/// 흐름:
///   1. server 가 응답 헤더 (X-App-Download-Url) 또는 GET /app-version 으로
///      pre-signed URL 전달
///   2. UpdateBlockerScreen/Banner 의 "Update" 탭 → [downloadAndInstall] 호출
///   3. Dio 가 APK 를 app cache dir 에 받는 동안 진행률 callback
///   4. 완료 후 open_filex 가 ACTION_VIEW intent (mime: vnd.android.package-archive)
///      발사 → OS PackageInstaller 가 "Install" 1탭 다이얼로그 노출
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

  /// APK 를 다운받아 PackageInstaller 로 띄운다.
  ///
  /// [url] : 다운로드 가능한 직접 URL (서버 발급 pre-signed URL).
  /// [onProgress] : 0.0 ~ 1.0 진행률 콜백. content-length 헤더가 없으면 발사 안 됨.
  /// throws : DioException / IOException / [AppInstallerException]
  static Future<void> downloadAndInstall(
    String url, {
    DownloadProgress? onProgress,
  }) async {
    final dir = await getApplicationCacheDirectory();
    final apkFile = File('${dir.path}/htma_update.apk');
    if (await apkFile.exists()) {
      // 이전 시도가 남아 있을 수 있음 — 새로 받기 전에 정리.
      await apkFile.delete();
    }

    final dio = Dio();
    await dio.download(
      _rewriteHostForClient(url),
      apkFile.path,
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

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw AppInstallerException(
        'OS install intent failed: ${result.type.name} — ${result.message}',
      );
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
