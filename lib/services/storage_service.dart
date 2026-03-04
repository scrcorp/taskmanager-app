/// 파일 업로드(Storage) 서비스
///
/// Supabase Storage 기반 Presigned URL 방식의 파일 업로드를 처리.
/// 1) 서버에서 presigned upload URL + 최종 file URL 발급받음
/// 2) 플랫폼별(Web/Native) 업로드 헬퍼로 파일 바이트를 PUT 전송
///
/// 조건부 임포트(conditional import)로 Web/Native/Stub 구현을 자동 선택.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
// 플랫폼별 업로드 헬퍼 선택: stub(기본) → web(dart:html) → native(dart:io)
import 'upload_helper_stub.dart'
    if (dart.library.html) 'upload_helper_web.dart'
    if (dart.library.io) 'upload_helper_native.dart' as uploader;

/// 스토리지 서비스 Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.read(dioProvider));
});

/// 파일 업로드 서비스 클래스
class StorageService {
  final Dio _dio;

  StorageService(this._dio);

  /// Presigned URL 발급 — 서버에 업로드 URL 요청
  ///
  /// [filename]: 원본 파일명 (서버가 고유 경로 생성)
  /// [contentType]: MIME 타입 (image/jpeg 등)
  /// [folder]: 저장 폴더 (기본: completions — 체크리스트 완료 사진용)
  /// 반환: { upload_url: PUT할 URL, file_url: 업로드 후 접근 URL }
  Future<Map<String, String>> getPresignedUrl(
    String filename,
    String contentType, {
    String folder = 'completions',
  }) async {
    final response = await _dio.post('/app/storage/presigned-url', data: {
      'filename': filename,
      'content_type': contentType,
      'folder': folder,
    });
    return {
      'upload_url': response.data['upload_url'] as String,
      'file_url': response.data['file_url'] as String,
    };
  }

  /// 파일 바이트를 presigned URL로 업로드
  ///
  /// 플랫폼별 구현이 자동 선택됨:
  /// - Web: dart:html HttpRequest PUT (CORS 호환)
  /// - Native(iOS/Android): Dio PUT
  /// - Stub: 지원 안 됨 (UnsupportedError)
  Future<void> uploadFile(
    String uploadUrl,
    Uint8List data,
    String contentType,
  ) async {
    await uploader.uploadBytes(uploadUrl, data, contentType);
  }
}
