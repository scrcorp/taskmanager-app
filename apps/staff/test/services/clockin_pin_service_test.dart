/// ClockinPinService unit tests.
///
/// Dio 의 httpClientAdapter 를 직접 fake 로 교체하여 HTTP 응답을 흉내냄.
/// (mockito 의존성 추가 없이 가능 — Dio 가 제공하는 정식 확장점)
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/services/clockin_pin_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler!(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late ClockinPinService service;

  setUp(() {
    dio = Dio();
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    service = ClockinPinService(dio);
  });

  group('getPin', () {
    test('returns clockin_pin payload', () async {
      adapter.handler = (req) {
        expect(req.method, 'GET');
        expect(req.path, '/app/profile/clockin-pin');
        return _json(200, {'user_id': 'u1', 'clockin_pin': '123456'});
      };

      final result = await service.getPin();
      expect(result['clockin_pin'], '123456');
      expect(result['user_id'], 'u1');
    });
  });

  group('regeneratePin', () {
    test('POSTs to /regenerate and returns new pin', () async {
      adapter.handler = (req) {
        expect(req.method, 'POST');
        expect(req.path, '/app/profile/clockin-pin/regenerate');
        return _json(200, {'user_id': 'u1', 'clockin_pin': '987654'});
      };

      final result = await service.regeneratePin();
      expect(result['clockin_pin'], '987654');
    });
  });

  group('updatePin', () {
    test('PUTs the given pin and returns response', () async {
      adapter.handler = (req) {
        expect(req.method, 'PUT');
        expect(req.path, '/app/profile/clockin-pin');
        return _json(200, {'user_id': 'u1', 'clockin_pin': '1234'});
      };

      final result = await service.updatePin('1234');
      expect(result['clockin_pin'], '1234');
    });

    test('throws Exception(pin_not_available) on 409', () async {
      adapter.handler = (_) => _json(409, {'detail': 'Not available'});

      await expectLater(
        () => service.updatePin('1234'),
        throwsA(predicate((e) => e is Exception && e.toString().contains('pin_not_available'))),
      );
    });

    test('throws Exception(pin_not_available) on 422', () async {
      adapter.handler = (_) => _json(422, {'detail': 'Validation failed'});

      await expectLater(
        () => service.updatePin('9999'),
        throwsA(predicate((e) => e is Exception && e.toString().contains('pin_not_available'))),
      );
    });

    test('rethrows other DioException (e.g. 500)', () async {
      adapter.handler = (_) => _json(500, {'detail': 'Server error'});

      await expectLater(
        () => service.updatePin('1234'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
