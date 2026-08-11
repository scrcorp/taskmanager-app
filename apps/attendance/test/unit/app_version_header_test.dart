/// X-App-Version 요청 헤더 인터셉터.
///
/// 이 헤더가 없으면 서버가 구버전으로 보고 force 를 강제한다(= 겹침 경고 확인
/// 흐름이 통째로 꺼진다). 그래서 "붙는다/안 붙는다"를 테스트로 못 박는다.

import 'dart:async';

import 'package:attendance/services/app_version_header_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RequestOptions> _run(AppVersionHeaderInterceptor i) async {
  final options = RequestOptions(path: '/attendance/manage/schedules');
  final completer = Completer<RequestOptions>();
  i.onRequest(options, _CaptureHandler(completer));
  return completer.future;
}

class _CaptureHandler extends RequestInterceptorHandler {
  final Completer<RequestOptions> completer;
  _CaptureHandler(this.completer);

  @override
  void next(RequestOptions options) => completer.complete(options);
}

void main() {
  test('버전을 읽으면 헤더가 붙는다', () async {
    final i = AppVersionHeaderInterceptor(readVersion: () async => '1.0.17+38');
    final out = await _run(i);
    expect(out.headers[kAppVersionHeader], '1.0.17+38');
  });

  test('헤더 이름은 서버 상수와 같아야 한다', () {
    // 어긋나면 서버는 "헤더 없음 = 구버전" 으로 보고 조용히 옛 동작을 준다.
    expect(kAppVersionHeader, 'X-App-Version');
  });

  test('버전을 못 읽으면 헤더를 빼고 그대로 진행한다 (요청을 막지 않는다)', () async {
    final i = AppVersionHeaderInterceptor(readVersion: () async => null);
    final out = await _run(i);
    expect(out.headers.containsKey(kAppVersionHeader), isFalse);
  });

  test('성공한 버전은 한 번만 읽고 캐시한다 (매 요청 플랫폼 채널 금지)', () async {
    var calls = 0;
    final i = AppVersionHeaderInterceptor(readVersion: () async {
      calls++;
      return '1.0.17+38';
    });
    await _run(i);
    await _run(i);
    await _run(i);
    expect(calls, 1);
  });

  test('실패는 캐시하지 않는다 — 기동 직후 한 번 실패해도 다음 요청에서 다시 읽는다', () async {
    var calls = 0;
    final i = AppVersionHeaderInterceptor(readVersion: () async {
      calls++;
      return calls == 1 ? null : '1.0.17+38';
    });
    final first = await _run(i);
    expect(first.headers.containsKey(kAppVersionHeader), isFalse);
    final second = await _run(i);
    expect(second.headers[kAppVersionHeader], '1.0.17+38');
    expect(calls, 2);
  });
}
