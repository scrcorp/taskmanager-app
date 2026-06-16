/// PDF 열기 헬퍼 — Stub(폴백) 구현.
///
/// dart:html(Web) 을 쓸 수 없는 환경(네이티브 등)에서 컴파일 에러 방지용.
/// 현재 staff 앱은 웹 배포라 실제로는 web 구현이 선택된다.
import 'dart:typed_data';

/// 지원되지 않는 플랫폼에서 호출 시 에러 발생.
Future<void> openPdfBytes(Uint8List bytes, {required String filename}) {
  throw UnsupportedError('Cannot open PDF without dart:html');
}
