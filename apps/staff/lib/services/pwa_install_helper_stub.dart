/// PWA 설치 헬퍼 — Stub(폴백) 구현
///
/// 네이티브(모바일/데스크톱) 빌드에는 "홈 화면에 추가" 개념이 없다.
/// 이미 설치된 앱이므로 설치 UI 자체를 숨기면 된다 → isStandalone = true.
/// pwa_install_service.dart 에서 조건부 임포트의 기본값으로 사용됨.
library;

/// 홈 화면 아이콘/설치된 앱으로 실행 중인가. 네이티브는 항상 true.
bool isStandalone() => true;

/// 네이티브 설치 프롬프트 가능 여부. 네이티브는 해당 없음.
bool canPrompt() => false;

/// iOS 웹(Safari) 여부. 네이티브는 해당 없음.
bool isIosWeb() => false;

/// 네이티브 설치 프롬프트 실행. 네이티브는 해당 없음.
Future<String> promptInstall() async => 'unavailable';
