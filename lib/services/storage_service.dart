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

  /// Upload file bytes to the presigned URL (no auth needed).
  Future<void> uploadFile(
    String uploadUrl,
    Uint8List data,
    String contentType,
  ) async {
    final uploadDio = Dio();
    await uploadDio.put(
      uploadUrl,
      data: data,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': data.length,
        },
      ),
    );
  }
}
