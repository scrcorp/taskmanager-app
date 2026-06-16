/// 경고(Warning) API 서비스.
///
/// staff 본인의 active 경고 목록/상세 조회, 서명, 미서명 카운트,
/// 저장된 서명 조회/저장을 처리한다.
/// 엔드포인트: /app/my/warnings/*
///
/// 주의: 상세 GET(`getDetail`) 호출 시 서버가 자동으로 acknowledge 처리한다.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/warning.dart';
import 'api_client.dart';

/// 경고 서비스 Provider
final warningServiceProvider = Provider<WarningService>((ref) {
  return WarningService(ref.read(dioProvider));
});

/// 경고 목록 조회 결과 (페이지네이션 메타 포함).
class WarningPage {
  final List<Warning> items;
  final int total;
  final int page;
  final int perPage;

  const WarningPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });
}

/// 경고 API 서비스 클래스
class WarningService {
  final Dio _dio;

  WarningService(this._dio);

  /// 내 active 경고 목록 — 페이지네이션 지원.
  Future<WarningPage> list({int page = 1, int perPage = 20}) async {
    final response = await _dio.get(
      '/app/my/warnings',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final data = response.data as Map<String, dynamic>;
    final items = ((data['items'] as List?) ?? const [])
        .map((e) => Warning.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return WarningPage(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      perPage: (data['per_page'] as num?)?.toInt() ?? perPage,
    );
  }

  /// 경고 상세 조회 — 서버가 이 호출에서 자동으로 acknowledge 처리한다.
  Future<Warning> getDetail(String id) async {
    final response = await _dio.get('/app/my/warnings/$id');
    return Warning.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// wet 서명된 PDF 바이트 조회 — 인증 헤더(dio)를 거쳐 받는다.
  ///
  /// 엔드포인트가 인증 게이트를 두므로 plain `<a href>` 로는 열 수 없다.
  /// 웹에서는 이 바이트로 blob URL 을 만들어 새 탭에서 연다.
  Future<Uint8List> getSignedPdf(String id) async {
    final response = await _dio.get<List<int>>(
      '/app/my/warnings/$id/signed-pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  /// 미서명(employee 서명 없는) 경고 수 — 배지/독촉용 (가벼운 API).
  Future<int> unsignedCount() async {
    final response = await _dio.get('/app/my/warnings/unsigned-count');
    return (response.data['unsigned_count'] as num?)?.toInt() ?? 0;
  }

  /// 저장된(기본) 서명 조회 — 없으면 null.
  Future<SignatureStrokes?> getSavedSignature() async {
    final response = await _dio.get('/app/my/warnings/saved-signature');
    final sig = response.data['signature'];
    if (sig == null) return null;
    return SignatureStrokes.fromJson((sig as Map).cast<String, dynamic>());
  }

  /// 저장된(기본) 서명 갱신.
  Future<SignatureStrokes> putSavedSignature(SignatureStrokes signature) async {
    final response = await _dio.put(
      '/app/my/warnings/saved-signature',
      data: signature.toJson(),
    );
    return SignatureStrokes.fromJson(
        (response.data['signature'] as Map).cast<String, dynamic>());
  }

  /// 경고 서명.
  ///
  /// [method] = 'drawn' (새로 그림) 또는 'saved' (저장된 서명 재사용).
  /// [saveAsDefault] = true 면 이 서명을 기본 서명으로 저장.
  Future<Warning> sign(
    String id, {
    required SignatureStrokes signature,
    required String method,
    bool saveAsDefault = false,
  }) async {
    final response = await _dio.post(
      '/app/my/warnings/$id/sign',
      data: {
        'strokes': signature.strokes,
        'aspect': signature.aspect,
        'method': method,
        'save_as_default': saveAsDefault,
      },
    );
    return Warning.fromJson((response.data as Map).cast<String, dynamic>());
  }
}
