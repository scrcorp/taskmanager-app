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

    test('409 pin_conflict(exact) — detail dict 보존한 PinUpdateException', () async {
      adapter.handler = (_) => _json(409, {
            'detail': {
              'code': 'pin_conflict',
              'reason': 'exact',
              'other_store': null,
              'message': 'This PIN is already in use by another employee.',
            },
          });

      await expectLater(
        () => service.updatePin('1234'),
        throwsA(predicate((e) =>
            e is PinUpdateException &&
            e.statusCode == 409 &&
            e.isPinConflict &&
            e.code == 'pin_conflict' &&
            e.reason == 'exact' &&
            e.detail['other_store'] == null &&
            e.detail['message'] ==
                'This PIN is already in use by another employee.')),
      );
    });

    test('409 pin_conflict(prefix) — reason 구분 보존', () async {
      adapter.handler = (_) => _json(409, {
            'detail': {
              'code': 'pin_conflict',
              'reason': 'prefix',
              'other_store': null,
              'message':
                  "This PIN overlaps with another employee's PIN (numbers that start the same).",
            },
          });

      await expectLater(
        () => service.updatePin('12345'),
        throwsA(predicate((e) =>
            e is PinUpdateException && e.isPinConflict && e.reason == 'prefix')),
      );
    });

    test('409 detail 이 dict 아님(문자열 fallback) — 빈 detail 로 보존', () async {
      adapter.handler = (_) => _json(409, {'detail': 'Not available'});

      await expectLater(
        () => service.updatePin('1234'),
        throwsA(predicate((e) =>
            e is PinUpdateException &&
            e.statusCode == 409 &&
            !e.isPinConflict &&
            e.detail.isEmpty)),
      );
    });

    test('422 — isInvalidFormat PinUpdateException', () async {
      adapter.handler = (_) => _json(422, {'detail': 'Validation failed'});

      await expectLater(
        () => service.updatePin('9999'),
        throwsA(predicate((e) =>
            e is PinUpdateException &&
            e.statusCode == 422 &&
            e.isInvalidFormat &&
            !e.isPinConflict)),
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
