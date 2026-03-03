import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Native (iOS/Android) — Dio PUT으로 업로드.
Future<void> uploadBytes(String url, Uint8List data, String contentType) async {
  final dio = Dio();
  await dio.put(
    url,
    data: data,
    options: Options(contentType: contentType),
  );
}
