/// 직원 의견(Voice) API 서비스
///
/// 의견 제출, 내 의견 목록 조회 API를 호출.
/// 엔드포인트: /app/my/voices
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice.dart';
import 'api_client.dart';

/// 의견 서비스 Provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref.read(dioProvider));
});

/// 직원 의견 API 서비스 클래스
class VoiceService {
  final Dio _dio;

  VoiceService(this._dio);

  /// 새 의견 제출 — 카테고리/우선순위 지정
  ///
  /// [category]: idea/facility/safety/hr/other 중 택1 (기본: idea)
  /// [priority]: normal/urgent (기본: normal)
  /// [storeId]: 특정 매장에 대한 의견일 때 지정 (선택)
  /// 반환: 생성된 Voice 객체 (서버가 id, 작성일 등 포함하여 응답)
  Future<Voice> createVoice({
    required String content,
    String category = 'idea',
    String priority = 'normal',
    String? storeId,
  }) async {
    final response = await _dio.post('/app/my/voices', data: {
      'content': content,
      'category': category,
      'priority': priority,
      if (storeId != null) 'store_id': storeId,
    });
    return Voice.fromJson(response.data);
  }

  /// 내 의견 목록 조회 — 페이지네이션 지원
  ///
  /// 응답 형식이 배열 또는 { items/data: [...] } 모두 대응.
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
