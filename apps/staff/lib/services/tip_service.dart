/// 본인용 Tips API 서비스 (직원 staff app).
///
/// 엔드포인트: /app/my/tips/*
/// - listEntries(start, end, storeId?) — 기간별 본인 entries
/// - createEntry(...) / updateEntry(...) — 본인 entry CRUD
/// - listIncoming(status?) — 받은 분배
/// - acceptDistribution(id) — OK 처리
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final tipServiceProvider = Provider<TipService>((ref) {
  return TipService(ref.read(dioProvider));
});

class TipService {
  final Dio _dio;
  TipService(this._dio);

  /// 본인 entries 조회 (기간 inclusive).
  Future<List<Map<String, dynamic>>> listEntries({
    required String start,
    required String end,
    String? storeId,
  }) async {
    final res = await _dio.get(
      '/app/my/tips/entries',
      queryParameters: {
        'start': start,
        'end': end,
        if (storeId != null) 'store_id': storeId,
      },
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 본인 entry 생성 — schedule_id 기반. server 가 store/work_role/date 자동 derive.
  Future<Map<String, dynamic>> createEntry({
    required String scheduleId,
    required String cardTips,
    required String cashTipsKept,
    List<Map<String, dynamic>> distributions = const [],
  }) async {
    final res = await _dio.post(
      '/app/my/tips/entries',
      data: {
        'schedule_id': scheduleId,
        'card_tips': cardTips,
        'cash_tips_kept': cashTipsKept,
        'source': 'staff_app',
        'distributions': distributions,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 본인 entry 수정. distributions 가 null 이면 분배는 유지.
  Future<Map<String, dynamic>> updateEntry({
    required String entryId,
    String? cardTips,
    String? cashTipsKept,
    List<Map<String, dynamic>>? distributions,
  }) async {
    final res = await _dio.patch(
      '/app/my/tips/entries/$entryId',
      data: {
        if (cardTips != null) 'card_tips': cardTips,
        if (cashTipsKept != null) 'cash_tips_kept': cashTipsKept,
        if (distributions != null) 'distributions': distributions,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 받은 분배 목록 — pending / accepted / auto_accepted 또는 전체.
  Future<List<Map<String, dynamic>>> listIncoming({String? status}) async {
    final res = await _dio.get(
      '/app/my/tips/distributions/incoming',
      queryParameters: status == null ? null : {'status': status},
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 분배 OK 처리.
  Future<Map<String, dynamic>> acceptDistribution(String distributionId) async {
    final res = await _dio.post(
      '/app/my/tips/distributions/$distributionId/accept',
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 본인 4070 폼 리스트.
  Future<List<Map<String, dynamic>>> listForms() async {
    final res = await _dio.get('/app/my/tips/forms');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// 4070 폼에 서명 적용. signature_image_key 는 storage upload 결과의 key.
  Future<Map<String, dynamic>> signForm({
    required String formId,
    required String signatureImageKey,
    bool saveForFuture = false,
  }) async {
    final res = await _dio.post(
      '/app/my/tips/forms/$formId/sign',
      data: {
        'signature_image_key': signatureImageKey,
        'save_for_future': saveForFuture,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 저장된 사인 조회.
  Future<Map<String, dynamic>> getSignature() async {
    final res = await _dio.get('/app/my/tips/signature');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 사인 등록/교체.
  Future<Map<String, dynamic>> updateSignature(String signatureImageKey) async {
    final res = await _dio.put(
      '/app/my/tips/signature',
      data: {'signature_image_key': signatureImageKey},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 사인 삭제.
  Future<void> clearSignature() async {
    await _dio.delete('/app/my/tips/signature');
  }
}
