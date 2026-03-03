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
  /// Returns {upload_url, file_url, key}.
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

  /// Upload file bytes via the app storage upload endpoint.
  /// Uses _dio (authenticated, correct baseUrl) to ensure the request
  /// reaches the server regardless of localhost/IP differences.
  Future<void> uploadFile(
    String uploadUrl,
    Uint8List data,
    String contentType,
  ) async {
    // Extract relative path from absolute upload URL.
    // uploadUrl: http://host:port/api/v1/app/storage/upload/temp/...
    // _dio.baseUrl: http://host:port/api/v1
    // We need: /app/storage/upload/temp/...
    final uri = Uri.parse(uploadUrl);
    var path = uri.path;
    const apiPrefix = '/api/v1';
    if (path.startsWith(apiPrefix)) {
      path = path.substring(apiPrefix.length);
    }

    await _dio.put(
      path,
      data: Stream.fromIterable([data]),
      options: Options(
        contentType: contentType,
        headers: {
          'Content-Length': data.length,
        },
      ),
    );
  }
}
