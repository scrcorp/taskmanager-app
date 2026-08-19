/// Unit tests — schedule_codes (D9 계약: 코드 + 파라미터).
///
/// 고정하려는 계약: **분기는 최상위 code 로만 한다.**
/// 409 는 급여 잠금·폐점·PIN 충돌도 쓰기 때문에, status 만 보고 "Save anyway" 를
/// 띄우면 넘길 수 없는 것을 넘길 수 있는 것처럼 보여주게 된다.

import 'package:attendance/utils/schedule_codes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(int status, dynamic body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
    );

void main() {
  group('parseScheduleFailure', () {
    test('409 경고 미확인 → 경고 목록과 함께 파싱', () {
      final f = parseScheduleFailure(_err(409, {
        'detail': {
          'code': kScheduleWarningsUnconfirmed,
          'message': 'ignored fallback text',
          'warnings': [
            {'code': kOverlappingSchedule, 'params': {'user_id': 'u-1'}},
            {'code': kShiftTooLong, 'params': {'limit_hours': 8}},
          ],
          'retry': {'force': true},
        }
      }));
      expect(f, isNotNull);
      expect(f!.isUnconfirmedWarnings, isTrue);
      expect(f.isInvalid, isFalse);
      expect(f.warnings.map((w) => w.code),
          [kOverlappingSchedule, kShiftTooLong]);
      expect(f.warnings[1].text, contains('8h'));
    });

    test('400 검증 실패 → 에러 목록, 확인으로 넘길 수 없다', () {
      final f = parseScheduleFailure(_err(400, {
        'detail': {
          'code': kScheduleInvalid,
          'message': 'fallback',
          'errors': [
            {'code': kTimeNotOnGrid, 'params': {'field': 'start_at', 'step_minutes': 5}},
          ],
          'warnings': [],
        }
      }));
      expect(f!.isInvalid, isTrue);
      expect(f.isUnconfirmedWarnings, isFalse);
      expect(f.errors.single.text, contains('5-minute'));
    });

    test('스케줄 계약이 아닌 409(급여 잠금 등)는 파싱하지 않는다', () {
      expect(parseScheduleFailure(_err(409, {'detail': 'pay_period_locked'})), isNull);
      expect(parseScheduleFailure(_err(409, {'detail': {'code': 'store_closed'}})), isNull);
    });

    test('응답 없는 에러(네트워크 등)는 null → 일반 처리로 폴백', () {
      expect(parseScheduleFailure(Exception('boom')), isNull);
      expect(
        parseScheduleFailure(DioException(requestOptions: RequestOptions(path: '/x'))),
        isNull,
      );
    });

    test('형태가 깨진 항목은 버리고 나머지를 살린다', () {
      final f = parseScheduleFailure(_err(409, {
        'detail': {
          'code': kScheduleWarningsUnconfirmed,
          'warnings': [
            'not-a-map',
            {'params': {}}, // code 없음
            {'code': kStoreClosedDay},
          ],
        }
      }));
      expect(f!.warnings.map((w) => w.code), [kStoreClosedDay]);
      expect(f.warnings.single.params, isEmpty);
    });
  });

  group('ScheduleIssue.text', () {
    test('모르는 코드는 문구를 지어내지 않고 코드를 그대로 보여준다', () {
      expect(const ScheduleIssue('SOME_NEW_SERVER_CODE').text, 'SOME_NEW_SERVER_CODE');
    });

    test('원인 + 다음 행동을 담는다', () {
      expect(const ScheduleIssue(kZeroDuration).text, contains('end time'));
      expect(const ScheduleIssue(kUserNotInStore).text, contains('another employee'));
      expect(const ScheduleIssue(kBreakOutsideShift).text, contains('remove'));
    });

    test('START_DATE_MISMATCH — 경계 이후 시작(자동값=영업일 당일)', () {
      final text = const ScheduleIssue(kStartDateMismatch, {
        'auto': '2026-08-10',
        'chosen': '2026-08-11',
        'boundary': '11:00',
        'start_time': '21:00',
        'operating_day': '2026-08-10',
        'suggested_operating_day': '2026-08-11',
      }).text;
      expect(text, contains('21:00 is on or after the 11:00 day start'));
      expect(text, contains('nobody can clock in'));
      // 400 이라 넘길 수 없다 — 고칠 대상은 날짜가 아니라 영업일이다.
      expect(text, contains('change the operating day to 2026-08-11'));
    });

    test('START_DATE_MISMATCH — 경계 이전 시작(자동값=영업일+1)', () {
      final text = const ScheduleIssue(kStartDateMismatch, {
        'auto': '2026-08-11',
        'chosen': '2026-08-10',
        'boundary': '11:00',
        'start_time': '09:00',
        'operating_day': '2026-08-10',
        'suggested_operating_day': '2026-08-09',
      }).text;
      expect(text, contains('09:00 is before the 11:00 day start'));
      expect(text, contains('change the operating day to 2026-08-09'));
    });

    test('START_DATE_MISMATCH — params 가 없으면 문구를 지어내지 않는다', () {
      final text = const ScheduleIssue(kStartDateMismatch).text;
      expect(text, contains('outside its operating day'));
      expect(text, contains('Change the operating day'));
    });
  });
}
