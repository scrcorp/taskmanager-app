import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.read(dioProvider));
});

class StorageService {
  final Dio _dio;

  StorageService(this._dio);

  /// Upload file via multipart form POST (로컬 모드).
  /// presigned URL 없이 직접 업로드. temp 경로에 저장됨.
  /// Returns file_url (temp URL, finalize_upload으로 최종 이동).
  Future<String> uploadFileMultipart(
    Uint8List data,
    String filename,
    String contentType, {
    String folder = 'completions',
  }) async {
    final formData = FormData.fromMap({
      'folder': folder,
      'file': MultipartFile.fromBytes(
        data,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await _dio.post('/app/storage/upload', data: formData);
    return response.data['file_url'] as String;
  }

  /// Get a presigned URL for S3 uploads.
  /// Returns {upload_url, file_url}.
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

  /// Upload raw bytes to S3 presigned URL.
  Future<void> uploadToPresignedUrl(
    String uploadUrl,
    Uint8List data,
    String contentType,
  ) async {
    final uploadDio = Dio();
    await uploadDio.put(
      uploadUrl,
      data: Stream.fromIterable([data]),
      options: Options(
        contentType: contentType,
        headers: {'Content-Length': data.length},
      ),
    );
  }
}
