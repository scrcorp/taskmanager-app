/// 웹 푸시 헬퍼 — Web 구현
///
/// web/push_bridge.js 가 window 에 심어 둔 `htmPush` 를 호출한다.
/// Push API 는 Promise/ArrayBuffer 를 오가므로 JS 층에서 JSON 문자열로
/// 정규화해 받는다 — Dart 쪽은 문자열만 다룬다.
///
/// 브리지가 없을 수도 있다(브라우저가 옛 index.html 을 캐시한 경우).
/// 그때는 "미지원" 으로 떨어뜨려 UI 가 조용히 숨도록 한다.
library;

import 'dart:js_interop';

extension type _HtmPush._(JSObject _) implements JSObject {
  external bool isSupported();
  external String permission();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSString> getSubscription();
  external JSPromise<JSString> subscribe(String vapidPublicKey);
  external JSPromise<JSString> unsubscribe();
}

@JS('htmPush')
external _HtmPush? get _bridge;

bool isSupported() {
  final bridge = _bridge;
  if (bridge == null) return false;
  try {
    return bridge.isSupported();
  } catch (_) {
    return false;
  }
}

String permission() {
  final bridge = _bridge;
  if (bridge == null) return 'unsupported';
  try {
    return bridge.permission();
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> _await(JSPromise<JSString>? promise, String fallback) async {
  if (promise == null) return fallback;
  try {
    return (await promise.toDart).toDart;
  } catch (_) {
    return fallback;
  }
}

Future<String> requestPermission() async =>
    _await(_bridge?.requestPermission(), 'denied');

Future<String> getSubscription() async => _await(_bridge?.getSubscription(), '');

Future<String> subscribe(String vapidPublicKey) async =>
    _await(_bridge?.subscribe(vapidPublicKey), 'ERROR:bridge-missing');

Future<String> unsubscribe() async => _await(_bridge?.unsubscribe(), '');
