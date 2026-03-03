import 'dart:typed_data';

/// Stub — 컴파일 시 platform에 따라 web 또는 native 구현으로 교체됩니다.
Future<void> uploadBytes(String url, Uint8List data, String contentType) {
  throw UnsupportedError('Cannot upload without dart:html or dart:io');
}
