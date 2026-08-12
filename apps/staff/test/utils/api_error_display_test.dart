/// Unit tests — staff 표시기 (`utils/api_error_display.dart`).
///
/// 파서 자체는 `packages/htm_core/test/api_error_test.dart` 가 검증한다.
/// 여기서는 실물 `DioException` 으로 staff 쪽 진입점 3개를 고정한다.
library;

import 'package:app/l10n/app_localizations_en.dart';
import 'package:app/utils/api_error_display.dart';
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

void main() {
  final t = AppL10nEn();

  test('문자열 detail 은 그대로 (구버전 서버 호환)', () {
    expect(extractApiError(_err(400, {'detail': 'Tips exceed the card total.'}), 'f'),
        'Tips exceed the card total.');
  });

  test('dict detail 이 와도 맵 덤프가 아니라 문장을 보여준다', () {
    // 예전 tip 편집기는 detail 을 그대로 `.toString()` 해서
    // `{code: ..., message: ...}` 가 사용자 화면에 찍혔다.
    final text = extractApiError(
        _err(409, {
          'detail': {'code': 'tip_locked', 'message': 'This tip period is closed.'}
        }),
        'Could not save. Try again.');
    expect(text, 'This tip period is closed.');
    expect(text, isNot(contains('{')));
  });

  test('설명이 붙은 400 에는 참조를 붙이지 않는다 (봉투가 와도)', () {
    // 봉투 도입 후엔 **모든** 응답에 trace_id 가 실린다. 그때마다 코드를 붙이면
    // 평범한 입력 오류에도 `BAD_REQUEST · T9` 가 따라붙어 500 의 신고 단서가 묻힌다.
    final text = extractApiError(
        _err(400, {
          'detail': 'Tips exceed the card total.',
          'error': {
            'code': 'BAD_REQUEST',
            'code_source': 'status',
            'message': 'Tips exceed the card total.',
            'trace_id': 'T9',
          },
        }),
        'f');
    expect(text, 'Tips exceed the card total.');
    expect(text, isNot(contains('T9')));
  });

  test('500 은 봉투가 와도 참조를 남긴다 (신고 경로)', () {
    final text = extractApiError(
        _err(500, {
          'detail': 'Something went wrong on our side.',
          'error': {
            'code': 'INTERNAL_ERROR',
            'code_source': 'status',
            'message': 'Something went wrong on our side.',
            'trace_id': 'T9',
          },
        }),
        'Could not save.');
    expect(text, contains('INTERNAL_ERROR · T9'));
  });

  test('5xx 는 내부 문장을 흘리지 않는다', () {
    expect(
      apiErrorTextOf(t, _err(500, {'detail': "NameError: name 'foo' is not defined"}),
          fallback: 'f'),
      t.errServerFault,
    );
  });

  test('네트워크 오류는 arb 문구 (es 사용자도 자기 언어로 본다)', () {
    final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError);
    expect(apiErrorTextOf(t, e, fallback: 'f'), t.errNetworkUnreachable);
    // l10n 없는 진입점은 예전처럼 호출부 fallback (영어 하드코딩을 만들지 않는다)
    expect(extractApiError(e, 'f'), 'f');
  });

  test('422 는 필드 사유를 보여준다', () {
    final err = parseApiError(_err(422, {
      'detail': [
        {'type': 'missing', 'loc': ['body', 'card_tips'], 'msg': 'Field required'},
      ],
    }));
    expect(err.code, kApiValidationError);
    expect(err.message, contains('card_tips'));
  });
}
