/// 웹 URL 전략 설정 — 웹/네이티브 양쪽 컴파일 가능한 추상화.
///
/// 기본값(해시)은 `/#/schedule` 형태라 **경로가 곧 라우트가 아니다.** 그래서
/// 알림 딥링크·공유 링크·주소 직접 입력이 전부 앱에 전달되지 않고
/// initialLocation('/home')으로 떨어졌다.
///
/// path 전략을 켜면 `/schedule` 이 그대로 라우트가 된다. 정적 호스팅이
/// 어떤 경로든 index.html 을 돌려줘야 하는데(SPA fallback), CloudFront 가
/// 이미 그렇게 동작하는 것을 확인했다(임의 경로 → 200).
///
/// 네이티브(Android/iOS)에서는 URL 개념이 없으므로 no-op.
export 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart';
