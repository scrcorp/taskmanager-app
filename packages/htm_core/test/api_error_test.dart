/// Unit tests — `parseApiError` (에러 봉투 계약, 2026-08-11).
///
/// 여기서 고정하려는 계약:
/// 1. `error`(봉투)가 **정본**, `detail` 은 레거시 미러. 둘 다 오면 `error` 를 읽는다.
/// 2. 봉투가 없어도(구버전 서버) 예전만큼은 읽는다 — 문자열/dict/422 배열 폴백.
/// 3. `code` 는 항상 있다. 도메인 코드가 아니면 `code_source: status` 로 구분되고,
///    표시기는 그때 **코드→문구 매핑을 하지 않는다.**
/// 4. `errors`/`warnings`/`retry`/`hint` 는 `params` 로 내려가지 않는다(E1-b 화이트리스트).
///
/// dio 를 import 하지 않는다 — 파서가 덕 타이핑으로 읽는 것을 그대로 검증한다.
/// (앱 쪽 테스트가 진짜 `DioException` 으로 한 번 더 검증한다.)

import 'package:flutter_test/flutter_test.dart';
import 'package:htm_core/htm_core.dart';

class _Resp {
  final int? statusCode;
  final dynamic data;
  const _Resp(this.statusCode, this.data);
}

class _HttpErr {
  final _Resp? response;
  const _HttpErr(this.response);
}

/// dio 의 `DioExceptionType` 자리 — 파서는 `toString()` 의 마지막 조각만 읽는다.
enum _DioType { connectionTimeout, connectionError, cancel, badCertificate }

class _TransportErr {
  final Object? response = null;
  final _DioType type;
  _TransportErr(this.type);
}

void main() {
  group('봉투(error)가 정본', () {
    test('detail 과 error 가 함께 오면 error 를 읽는다', () {
      final err = parseApiError(_HttpErr(const _Resp(400, {
        'detail': 'legacy sentence',
        'error': {
          'code': 'BREAK_TOO_LONG',
          'code_source': 'domain',
          'message': 'The break is longer than the shift.',
          'hint': 'Shorten the break.',
          'params': {'minutes': 90},
          'trace_id': '01J9F3K2QW',
        },
      })));
      expect(err.code, 'BREAK_TOO_LONG');
      expect(err.source, ApiErrorSource.domain);
      expect(err.message, 'The break is longer than the shift.');
      expect(err.hint, 'Shorten the break.');
      expect(err.params['minutes'], 90);
      expect(err.traceId, '01J9F3K2QW');
      expect(err.statusCode, 400);
      expect(err.fromEnvelope, isTrue);
      expect(err.reference, 'BREAK_TOO_LONG · 01J9F3K2QW');
    });

    test('code_source: status 면 도메인이 아니다 — 표시기가 문구를 만들면 안 되는 신호', () {
      final err = parseApiError(_HttpErr(const _Resp(400, {
        'detail': 'Break end must be after break start.',
        'error': {
          'code': 'BAD_REQUEST',
          'code_source': 'status',
          'message': 'Break end must be after break start.',
          'trace_id': 'abc',
        },
      })));
      expect(err.isDomain, isFalse);
      expect(err.message, 'Break end must be after break start.');
    });

    test('errors/warnings/retry 는 최상위로 유지된다 (params 로 내려가지 않는다)', () {
      final err = parseApiError(_HttpErr(const _Resp(409, {
        'error': {
          'code': 'SCHEDULE_WARNINGS_UNCONFIRMED',
          'code_source': 'domain',
          'message': 'overlap',
          'warnings': [
            {'code': 'OVERLAPPING_SCHEDULE', 'params': {'user_id': 'u-1'}},
          ],
          'retry': {'force': true},
        },
      })));
      expect(err.warnings.single.code, 'OVERLAPPING_SCHEDULE');
      expect(err.warnings.single.params['user_id'], 'u-1');
      expect(err.retry, {'force': true});
      expect(err.params, isEmpty);
    });

    test('봉투의 미지 최상위 키도 params 로 보존한다 (정보 소실 금지)', () {
      final err = parseApiError(_HttpErr(const _Resp(400, {
        'error': {
          'code': 'X',
          'code_source': 'domain',
          'minutes_early': 23,
        },
      })));
      expect(err.params['minutes_early'], 23);
    });

    test('code 가 비면 status 로 떨어진다 — 코드를 지어내지 않는다', () {
      final err = parseApiError(_HttpErr(const _Resp(404, {
        'error': {'code': '', 'code_source': 'domain'},
      })));
      expect(err.code, kApiNotFound);
      expect(err.source, ApiErrorSource.status);
    });
  });

  group('레거시 detail 폴백 (구버전 서버)', () {
    test('문자열 detail — 지금과 동일하게 보인다', () {
      final err = parseApiError(
          _HttpErr(const _Resp(400, {'detail': 'Break end must be after break start.'})));
      expect(err.message, 'Break end must be after break start.');
      expect(err.code, kApiBadRequest);
      expect(err.source, ApiErrorSource.status);
      expect(err.fromEnvelope, isFalse);
    });

    test('dict detail — code 는 domain, 평탄 부가필드는 params 로 모인다', () {
      final err = parseApiError(_HttpErr(const _Resp(409, {
        'detail': {
          'code': 'early_clock_in_reason_required',
          'minutes_early': 23,
          'schedule_id': 's-1',
          'message': 'Clocking in early requires a reason.',
        },
      })));
      expect(err.code, 'early_clock_in_reason_required');
      expect(err.source, ApiErrorSource.domain);
      expect(err.message, 'Clocking in early requires a reason.');
      expect(err.params['minutes_early'], 23);
      expect(err.params['schedule_id'], 's-1');
    });

    test('code 만 있고 message 가 없으면 문구를 지어내지 않는다 (코드로 추적)', () {
      final err = parseApiError(
          _HttpErr(const _Resp(409, {'detail': {'code': 'pin_conflict'}})));
      expect(err.code, 'pin_conflict');
      expect(err.hasMessage, isFalse);
      expect(err.reference, 'pin_conflict');
    });

    test('422 배열 detail → VALIDATION_ERROR + 필드 목록', () {
      final err = parseApiError(_HttpErr(const _Resp(422, {
        'detail': [
          {'type': 'int_parsing', 'loc': ['body', 'n'], 'msg': 'not an integer', 'input': 'x'},
        ],
      })));
      expect(err.code, kApiValidationError);
      expect(err.message, 'n: not an integer');
      expect((err.params['fields'] as List).single, {'field': 'n', 'reason': 'int_parsing'});
    });

    test('text/plain 500 (구버전 서버) — body 문자열을 문장으로 읽고 서버 오류로 분류', () {
      final err = parseApiError(_HttpErr(const _Resp(500, 'Internal Server Error')));
      expect(err.code, kApiInternalError);
      expect(err.isServerFault, isTrue);
      expect(err.fromEnvelope, isFalse);
    });

    test('body 가 없어도 status 로 코드가 나온다', () {
      final err = parseApiError(_HttpErr(const _Resp(403, null)));
      expect(err.code, kApiForbidden);
      expect(err.isForbidden, isTrue);
      expect(err.hasMessage, isFalse);
    });
  });

  group('transport (서버까지 못 감)', () {
    test('타임아웃/연결실패/취소가 서로 다른 코드', () {
      expect(parseApiError(_TransportErr(_DioType.connectionTimeout)).code,
          kApiNetworkTimeout);
      expect(parseApiError(_TransportErr(_DioType.connectionError)).code,
          kApiNetworkUnreachable);
      expect(parseApiError(_TransportErr(_DioType.cancel)).code, kApiRequestCancelled);
      expect(parseApiError(_TransportErr(_DioType.badCertificate)).code,
          kApiNetworkInsecure);
    });

    test('HTTP 예외가 아닌 것도 파서가 삼킨다 (화면이 추측하지 않게)', () {
      final err = parseApiError(Exception('boom'));
      expect(err.code, kApiNetworkError);
      expect(err.isTransport, isTrue);
      expect(err.statusCode, isNull);
    });
  });
}
