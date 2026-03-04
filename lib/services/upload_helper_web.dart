/// 파일 업로드 헬퍼 — Web 구현
///
/// dart:html의 HttpRequest를 사용하여 presigned URL에 PUT 요청.
/// Dio 대신 브라우저 네이티브 API를 사용하는 이유:
/// 웹에서 Blob/FormData 처리 및 CORS 호환성이 더 안정적.
/// storage_service.dart에서 조건부 임포트로 자동 선택됨.
import 'dart:html' as html;
import 'dart:typed_data';

/// presigned URL에 파일 바이트를 PUT 업로드 (Web 브라우저)
///
/// Blob으로 감싸서 전송하며, 200~299 외 응답은 예외 발생.
Future<void> uploadBytes(String url, Uint8List data, String contentType) async {
  final request = await html.HttpRequest.request(
    url,
    method: 'PUT',
    sendData: html.Blob([data], contentType),
    requestHeaders: {'Content-Type': contentType},
  );
  if (request.status! < 200 || request.status! >= 300) {
    throw Exception('Upload failed: ${request.status} ${request.statusText}');
  }
}
