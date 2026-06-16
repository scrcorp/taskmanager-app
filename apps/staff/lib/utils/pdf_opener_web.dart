/// PDF 열기 헬퍼 — Web 구현.
///
/// 인증 게이트된 엔드포인트에서 dio 로 받은 PDF 바이트를 Blob 으로 감싸
/// object URL 을 만들고 새 탭에서 연다(브라우저 내장 PDF 뷰어).
/// plain `<a href>` 로는 Authorization 헤더를 못 붙이므로 이 방식을 쓴다.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// PDF 바이트를 새 브라우저 탭에서 연다.
///
/// object URL 은 새 탭이 받아간 뒤 일정 시간 후 해제한다(즉시 revoke 시 일부
/// 브라우저에서 탭 로드가 끊길 수 있어 지연 해제).
Future<void> openPdfBytes(Uint8List bytes, {required String filename}) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // 새 탭이 로드를 시작할 시간을 준 뒤 URL 해제(메모리 누수 방지).
  Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
}
