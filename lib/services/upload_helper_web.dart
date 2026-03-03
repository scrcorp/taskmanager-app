import 'dart:html' as html;
import 'dart:typed_data';

/// Web — dart:html의 HttpRequest로 PUT (admin의 fetch()와 동일 방식).
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
