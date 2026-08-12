/// Unit tests — HTMA 표시기 (`utils/api_error_display.dart`).
///
/// 파서 자체는 `packages/htm_core/test/api_error_test.dart` 가 검증한다.
/// 여기서 고정하는 것:
/// 1. **진짜 `DioException`** 으로도 파서가 동작한다(덕 타이핑이 실물에서 깨지지 않는지).
/// 2. `extractApiError` 의 시그니처·기존 동작 보존 — 문자열 detail 은 예전과 동일.
/// 3. 봉투/구조화 detail 이 오면 예전엔 못 보던 사유를 보여준다(이 교체의 실익).
/// 4. 서버가 문장을 안 줬거나 5xx 면 **내부 문장을 흘리지 않고** 코드·trace 만 남긴다.

import 'package:attendance/l10n/app_localizations_en.dart';
import 'package:attendance/utils/api_error_display.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:htm_core/htm_core.dart';

DioException _err(int status, dynamic body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
    );

DioException _transport(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
    );

void main() {
  final t = AppL10nEn();

  group('extractApiError — 기존 동작 보존', () {
    test('문자열 detail 은 예전과 100% 동일하게 나온다', () {
      expect(
        extractApiError(_err(400, {'detail': 'Break end must be after break start.'}),
            'fallback'),
        'Break end must be after break start.',
      );
    });

    test('네트워크 오류는 예전처럼 호출부 fallback', () {
      expect(extractApiError(_transport(DioExceptionType.connectionError), 'fallback'),
          'fallback');
      expect(extractApiError(Exception('boom'), 'fallback'), 'fallback');
    });

    test('봉투 없는 5xx 는 fallback — text/plain "Internal Server Error" 를 그대로 안 보인다', () {
      final text = extractApiError(_err(500, 'Internal Server Error'), 'Could not save.');
      expect(text, startsWith('Could not save.'));
      expect(text, contains(kApiInternalError));
    });
  });

  group('extractApiError — 새로 보이게 되는 것', () {
    test('구조화 detail 의 message 를 보여준다 (예전엔 fallback 이었다)', () {
      expect(
        extractApiError(
            _err(409, {
              'detail': {
                'code': 'early_clock_in_reason_required',
                'message': 'Clocking in early requires a reason.',
                'minutes_early': 23,
              }
            }),
            'fallback'),
        'Clocking in early requires a reason.',
      );
    });

    test('봉투가 와도 설명이 붙은 400 엔 코드·trace_id 를 붙이지 않는다', () {
      // 키오스크 화면이라 손님도 본다. 봉투 도입 후엔 모든 응답에 trace_id 가
      // 실리므로, trace_id 유무로 참조를 붙이면 평범한 입력 오류마다 코드가 뜬다.
      final text = extractApiError(
          _err(400, {
            'detail': 'Break end must be after break start.',
            'error': {
              'code': 'BAD_REQUEST',
              'code_source': 'status',
              'message': 'Break end must be after break start.',
              'trace_id': '01J9F3K2QW',
            },
          }),
          'fallback');
      expect(text, 'Break end must be after break start.');
      expect(text, isNot(contains('01J9F3K2QW')));
    });

    test('message 없이 code 만 오면 문구를 지어내지 않고 코드를 남긴다', () {
      final text = extractApiError(_err(409, {'detail': {'code': 'pin_conflict'}}),
          'Could not save the PIN.');
      expect(text, startsWith('Could not save the PIN.'));
      expect(text, contains('pin_conflict'));
    });
  });

  group('apiErrorText — l10n 문구', () {
    test('transport 는 종류별로 다른 안내', () {
      expect(apiErrorTextOf(t, _transport(DioExceptionType.connectionError), fallback: 'f'),
          t.errNetworkUnreachable);
      expect(apiErrorTextOf(t, _transport(DioExceptionType.receiveTimeout), fallback: 'f'),
          t.errNetworkTimeout);
    });

    test('5xx 는 서버 문장 대신 일반 문구 — 내부 예외 메시지를 사용자에게 흘리지 않는다', () {
      expect(
        apiErrorTextOf(
            t,
            _err(500, {
              'detail': "NameError: name 'foo' is not defined",
              'error': {
                'code': 'INTERNAL_ERROR',
                'code_source': 'status',
                'message': "NameError: name 'foo' is not defined",
                'trace_id': 'abc',
              },
            }),
            fallback: 'f'),
        t.errServerFault,
      );
    });

    test('status 코드는 서버 문장을 그대로 띄운다 (코드→문구 매핑 금지)', () {
      expect(
        apiErrorTextOf(t, _err(400, {'detail': 'This store is closed today.'}),
            fallback: 'f'),
        'This store is closed today.',
      );
    });

    test('문장이 없으면 호출부 맥락 문장', () {
      expect(apiErrorTextOf(t, _err(409, {'detail': {'code': 'pin_conflict'}}),
          fallback: 'Could not save the PIN.'),
          'Could not save the PIN.');
    });
  });

  group('apiErrorReference — 하단 회색 한 줄 (500 + 모르는 코드에만)', () {
    test('500 이면 코드·trace_id 를 남긴다 (사진 신고 경로)', () {
      final err = parseApiError(_err(500, {
        'error': {
          'code': 'INTERNAL_ERROR',
          'code_source': 'status',
          'message': 'm',
          'trace_id': 'T1',
        },
      }));
      expect(apiErrorReference(err), 'INTERNAL_ERROR · T1');
    });

    test('문구가 있으면 trace_id 가 와도 노출하지 않는다 — 참조는 500/모르는 코드 전용', () {
      // 콘솔 errorDisplay.ts 의 needsReference 와 같은 규칙.
      final err = parseApiError(_err(400, {
        'error': {'code': 'X', 'code_source': 'domain', 'message': 'm', 'trace_id': 'T1'},
      }));
      expect(apiErrorReference(err), isNull);
    });

    test('문구가 없으면 trace_id 와 함께 코드를 남긴다 (무엇이 걸렸는지는 알아야 한다)', () {
      final err = parseApiError(_err(409, {
        'error': {'code': 'weird_code', 'code_source': 'domain', 'trace_id': 'T2'},
      }));
      expect(apiErrorReference(err), 'weird_code · T2');
    });

    test('문구가 정상인 도메인 에러는 코드를 노출하지 않는다 (화면이 지저분해진다)', () {
      final err = parseApiError(_err(409, {
        'detail': {'code': 'early_clock_in_reason_required', 'message': 'reason required'},
      }));
      expect(apiErrorReference(err), isNull);
    });

    test('네트워크 오류엔 보여줄 참조가 없다', () {
      expect(apiErrorReference(parseApiError(_transport(DioExceptionType.connectionError))),
          isNull);
    });
  });

  group('isManageSessionEnded — manage 모드 이탈 판정', () {
    test('401/403 이면 세션 종료 — 문구에 session/expired 가 없어도 갇히지 않는다', () {
      // 서버 deps.py 의 5개 문구 중 3개엔 'session'/'expired' 가 없다.
      // 예전 문자열 판정은 이때 false 를 내서 매니저가 manage 모드에 갇혔다.
      expect(isManageSessionEnded(_err(401, {'detail': 'Device store has changed; please re-enter manager mode'})),
          isTrue);
      expect(isManageSessionEnded(_err(403, {'detail': 'Manager no longer authorized'})),
          isTrue);
    });

    test('문자열 판정도 아직 살아 있다 (서버 코드 부여 전까지)', () {
      expect(isManageSessionEnded(_err(400, {'detail': 'Your session has expired'})), isTrue);
    });

    test('네트워크 오류로 manage 모드를 빠져나오면 안 된다', () {
      expect(isManageSessionEnded(_transport(DioExceptionType.connectionError)), isFalse);
    });

    test('무관한 400 은 세션 종료가 아니다', () {
      expect(isManageSessionEnded(_err(400, {'detail': 'Break end must be after break start.'})),
          isFalse);
    });
  });
}
