/// PWA "홈 화면에 추가" 설치 서비스
///
/// 플랫폼별로 설치 방법이 완전히 다르다:
///  - Chrome 계열: beforeinstallprompt 를 잡아 두었다가 네이티브 설치창을 띄운다
///  - iOS Safari: 프로그래밍 방식 설치 API 가 아예 없다 → 공유 버튼 수동 안내뿐
///  - 이미 설치됨 / 네이티브 빌드: 설치 UI 를 숨긴다
///
/// 화면은 [PwaInstallMode] 하나만 보고 무엇을 그릴지 결정하면 된다.
library;

import 'pwa_install_helper_stub.dart'
    if (dart.library.html) 'pwa_install_helper_web.dart' as helper;

/// 설치 UI 를 어떤 모양으로 보여줄지.
enum PwaInstallMode {
  /// 설치 UI 를 띄우지 않는다 — 이미 설치됨, 네이티브 빌드,
  /// 또는 설치를 지원하지 않는 브라우저.
  hidden,

  /// 네이티브 설치창을 띄울 수 있다 (Chrome 계열).
  prompt,

  /// iOS — "공유 → 홈 화면에 추가" 수동 안내가 필요하다.
  iosManual,
}

/// 설치 프롬프트 결과.
enum PwaInstallResult { accepted, dismissed, unavailable }

class PwaInstallService {
  const PwaInstallService();

  /// 홈 화면 아이콘(또는 설치된 앱)으로 실행 중인가.
  bool get isStandalone => helper.isStandalone();

  /// 지금 화면에 그려야 할 설치 UI 모양.
  ///
  /// 이미 설치된 상태면 무조건 hidden — iOS 라도 안내를 띄우지 않는다.
  PwaInstallMode get mode {
    if (helper.isStandalone()) return PwaInstallMode.hidden;
    if (helper.canPrompt()) return PwaInstallMode.prompt;
    if (helper.isIosWeb()) return PwaInstallMode.iosManual;
    return PwaInstallMode.hidden;
  }

  /// 네이티브 설치창을 띄운다.
  ///
  /// 반드시 사용자 탭 제스처 안에서 호출해야 한다 — 브라우저가 그 외의 호출은
  /// 무시한다. 프롬프트는 1회용이라 호출 후 [mode] 는 hidden 으로 바뀐다.
  Future<PwaInstallResult> promptInstall() async {
    final outcome = await helper.promptInstall();
    switch (outcome) {
      case 'accepted':
        return PwaInstallResult.accepted;
      case 'unavailable':
        return PwaInstallResult.unavailable;
      default:
        return PwaInstallResult.dismissed;
    }
  }
}
