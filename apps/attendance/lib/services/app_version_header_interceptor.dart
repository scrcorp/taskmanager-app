/// 모든 device 요청에 `X-App-Version` 을 실어 보내는 인터셉터.
///
/// **왜 필요한가.**
/// HTMA 는 사이드로드 APK 라 구버전이 오래 살아남는다. 서버는 이 헤더를 보고
/// "겹침 경고 확인 흐름(D9-1)을 아는 클라이언트인지" 판단한다
/// (server `app/core/app_version_compat.py`, HTMA_FORCE_FIELD_MIN_VERSION=1.0.17).
///   - 헤더가 없거나 1.0.17 미만 → 서버가 `force=True` 를 강제한다(= 예전처럼 겹침을
///     확인 없이 저장). 확인 모달이 없는 구버전에게 409 를 주면 원인 모를 저장 실패로
///     보이기 때문이다.
///   - 1.0.17 이상 → 클라가 보낸 force 를 그대로 존중한다(409 확인 흐름 활성).
///
/// 그래서 **헤더 전송과 409 확인 모달은 같은 릴리스에 실려야 한다.** 헤더만 붙이고
/// 확인 모달이 없으면 매니저가 겹침 스케줄을 아예 저장하지 못한다.
///
/// 값 형식은 업데이트 게이트가 쓰는 것과 동일한 "1.0.17+38"(semver+build).
/// 두 곳이 다른 형식을 쓰면 같은 앱이 서버에 두 얼굴로 보인다 —
/// [currentVersionString] 하나만 쓴다.
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_version_gate.dart' show currentVersionString;

/// 서버 `APP_VERSION_HEADER` 와 같은 이름이어야 한다. 어긋나면 서버는 헤더가
/// 없는 것으로 보고 구버전 취급한다(조용한 실패).
const String kAppVersionHeader = 'X-App-Version';

/// 요청 단위로 붙는다 — manage 스케줄뿐 아니라 **전 요청**에 붙인다.
/// 앞으로 서버가 min_version 426 하드 게이트를 붙일 때 특정 화면만 막히는 일이
/// 없도록, 판단 근거를 전 요청에 일관되게 실어 두는 편이 안전하다.
class AppVersionHeaderInterceptor extends Interceptor {
  final Future<String?> Function() _readVersion;

  /// 버전 조회는 플랫폼 채널이라 매 요청 하지 않고 한 번만 하고 캐시한다.
  Future<String?>? _pending;

  AppVersionHeaderInterceptor({Future<String?> Function()? readVersion})
      : _readVersion = readVersion ?? readPackageVersion;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final version = await (_pending ??= _readVersion());
    if (version != null && version.isNotEmpty) {
      options.headers[kAppVersionHeader] = version;
    } else {
      // 실패를 영구 캐시하지 않는다. 앱 기동 직후 플러그인이 아직 준비되지 않아
      // 한 번 실패하면, 그대로 캐시할 경우 그 세션 내내 구버전으로 취급된다.
      _pending = null;
    }
    handler.next(options);
  }
}

/// PackageInfo 에서 "1.0.17+38" 을 읽는다. 실패하면 null —
/// 헤더를 빼는 쪽이 안전하다(서버가 구버전으로 보고 예전 동작을 준다).
Future<String?> readPackageVersion() async {
  try {
    return currentVersionString(await PackageInfo.fromPlatform());
  } catch (_) {
    return null;
  }
}
