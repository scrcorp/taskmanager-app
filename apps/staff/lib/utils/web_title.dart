/// 브라우저 탭 타이틀 설정 — 웹/네이티브 양쪽 컴파일 가능한 추상화
///
/// 네이티브(Android/iOS)에서는 no-op. 웹에서만 document.title 변경.
export 'web_title_stub.dart' if (dart.library.html) 'web_title_web.dart';
