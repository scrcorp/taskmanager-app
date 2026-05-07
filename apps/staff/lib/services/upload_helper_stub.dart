/// 파일 업로드 헬퍼 — Stub(폴백) 구현
///
/// dart:html(Web)도 dart:io(Native)도 사용할 수 없는 환경에서
/// 컴파일 에러 방지를 위한 기본 구현. 호출 시 UnsupportedError 발생.
/// storage_service.dart에서 조건부 임포트의 기본값으로 사용됨.
import 'dart:typed_data';

/// 지원되지 않는 플랫폼에서 호출 시 에러 발생
Future<void> uploadBytes(String url, Uint8List data, String contentType) {
  throw UnsupportedError('Cannot upload without dart:html or dart:io');
}
