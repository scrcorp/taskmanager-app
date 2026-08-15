/// PWA 설치 헬퍼 — Web 구현
///
/// web/index.html 에서 미리 심어 둔 `window.htmPwa` 브리지를 호출한다.
/// beforeinstallprompt 는 Flutter 부팅보다 먼저 발화할 수 있어 Dart 에서 직접
/// 리스닝할 수 없다 — 그래서 index.html 이 이벤트를 붙잡아 보관하고, 여기서는
/// 보관된 것을 읽어 쓰기만 한다.
///
/// 브리지가 없을 수도 있다(브라우저가 옛 index.html 을 캐시한 경우). 그때는
/// 설치 UI 를 조용히 숨기는 쪽이 안전하므로 모든 함수가 안전한 기본값을 준다.
library;

import 'dart:js_interop';

/// index.html 이 window 에 심어 둔 브리지 객체.
extension type _HtmPwa._(JSObject _) implements JSObject {
  external bool isStandalone();
  external bool canPrompt();
  external bool isIos();
  external JSPromise<JSString> prompt();
}

@JS('htmPwa')
external _HtmPwa? get _bridge;

/// 브리지의 bool 메서드를 안전하게 호출 — 브리지가 없거나 던지면 [fallback].
bool _callBool(bool Function(_HtmPwa) fn, {required bool fallback}) {
  final bridge = _bridge;
  if (bridge == null) return fallback;
  try {
    return fn(bridge);
  } catch (_) {
    return fallback;
  }
}

/// 홈 화면 아이콘(또는 설치된 앱)으로 실행 중인가.
///
/// 브리지가 없으면 true 를 돌려준다 — 설치 안내를 잘못 띄우느니 숨기는 게 낫다.
bool isStandalone() =>
    _callBool((b) => b.isStandalone(), fallback: true);

/// 네이티브 설치 프롬프트를 띄울 수 있는 상태인가 (Chrome 계열).
bool canPrompt() => _callBool((b) => b.canPrompt(), fallback: false);

/// iOS 계열 웹인가 — 수동 안내(공유 → 홈 화면에 추가)가 필요한지 판단용.
bool isIosWeb() => _callBool((b) => b.isIos(), fallback: false);

/// 네이티브 설치 프롬프트 실행.
///
/// Returns: 'accepted' | 'dismissed' | 'unavailable'
/// 프롬프트는 1회용이라 한 번 호출하면 이후 [canPrompt] 는 false 가 된다.
Future<String> promptInstall() async {
  final bridge = _bridge;
  if (bridge == null) return 'unavailable';
  try {
    final outcome = await bridge.prompt().toDart;
    return outcome.toDart;
  } catch (_) {
    return 'dismissed';
  }
}
