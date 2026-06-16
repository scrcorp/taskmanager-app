/// 서명된 PDF 바이트를 브라우저/디바이스에서 열기 위한 추상화.
///
/// wet 서명 문서 다운로드 엔드포인트는 인증 헤더가 필요해 plain `<a href>` 로
/// 열 수 없다. 그래서 dio 로 바이트를 받은 뒤 이 헬퍼로 연다.
///   - 웹: Blob URL 생성 → 새 탭에서 브라우저 내장 PDF 뷰어로 오픈.
///   - 네이티브/그 외: stub (현재 staff 앱은 웹 배포라 미사용).
///
/// 조건부 임포트로 Web/Stub 구현을 자동 선택. (web_title.dart 와 동일 패턴)
export 'pdf_opener_stub.dart' if (dart.library.html) 'pdf_opener_web.dart';
