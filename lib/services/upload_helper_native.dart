/// 파일 업로드 헬퍼 — Native(iOS/Android) 구현
///
/// Dio를 사용하여 presigned URL에 PUT 요청으로 파일 바이트 업로드.
/// storage_service.dart에서 조건부 임포트로 자동 선택됨.
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// presigned URL에 파일 바이트를 PUT 업로드 (iOS/Android)
Future<void> uploadBytes(String url, Uint8List data, String contentType) async {
  final dio = Dio();
  await dio.put(
    url,
    data: data,
    options: Options(contentType: contentType),
  );
}
