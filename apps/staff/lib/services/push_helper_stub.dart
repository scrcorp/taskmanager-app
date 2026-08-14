/// 웹 푸시 헬퍼 — Stub(폴백) 구현
///
/// 네이티브 빌드에는 브라우저 Push API 가 없다. 기능을 꺼진 것으로 보고
/// UI 가 푸시 항목 자체를 숨기게 한다.
library;

bool isSupported() => false;

String permission() => 'unsupported';

Future<String> requestPermission() async => 'unsupported';

Future<String> getSubscription() async => '';

Future<String> subscribe(String vapidPublicKey) async => 'ERROR:unsupported';

Future<String> unsubscribe() async => '';
