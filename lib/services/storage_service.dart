import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'upload_helper_stub.dart'
    if (dart.library.html) 'upload_helper_web.dart'
    if (dart.library.io) 'upload_helper_native.dart' as uploader;

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.read(dioProvider));
});

class StorageService {
  final Dio _dio;

  StorageService(this._dio);

  /// Get a presigned URL for uploading a file.
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

  /// Upload file bytes to the presigned URL.
  /// Web: dart:html HttpRequest로 직접 PUT (fetch API와 동일).
  /// Native: Dio PUT으로 업로드.
  Future<void> uploadFile(
    String uploadUrl,
    Uint8List data,
    String contentType,
  ) async {
    await uploader.uploadBytes(uploadUrl, data, contentType);
  }
}
