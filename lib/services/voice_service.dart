import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice.dart';
import 'api_client.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref.read(dioProvider));
});

class VoiceService {
  final Dio _dio;

  VoiceService(this._dio);

  Future<Voice> createVoice({
    required String title,
    String? description,
    String category = 'idea',
    String priority = 'normal',
    String? storeId,
  }) async {
    final response = await _dio.post('/app/my/voices', data: {
      'title': title,
      if (description != null) 'description': description,
      'category': category,
      'priority': priority,
      if (storeId != null) 'store_id': storeId,
    });
    return Voice.fromJson(response.data);
  }

  Future<List<Voice>> getMyVoices({int? page, int? perPage}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (perPage != null) params['per_page'] = perPage;

    final response =
        await _dio.get('/app/my/voices', queryParameters: params);
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Voice.fromJson(e)).toList();
  }
}
