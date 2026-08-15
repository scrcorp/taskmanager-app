/// shift 선택 pure logic unit test (계약 §1 / §3, 페이즈 ④⑤).
///
/// 이 파일이 지키는 것: **앱은 판정하지 않는다.** 프리뷰 숫자는 서버가 준 값을
/// 그대로 옮길 뿐이고, 여기 테스트는 "옮기는 규칙"과 "고를 수 있는지"만 본다.
/// 앱이 몇 분 지각인지 스스로 세기 시작하면 초 버림 지점이 하나 더 생겨
/// 화면과 기록이 갈린다 — 이 트랙이 고치려던 병이 그대로 재발한다.

import 'package:attendance/models/identify_response.dart';
import 'package:attendance/utils/shift_pick_logic.dart';
import 'package:flutter_test/flutter_test.dart';

TodayAttendanceItem _item(
  String id, {
  String status = 'upcoming',
  bool eligible = true,
  String? ineligibleReason,
  bool isDefault = false,
  bool overlapping = false,
  ClockInPreview? preview,
  String? operatingDay,
}) =>
    TodayAttendanceItem(
      scheduleId: id,
      status: status,
      clockInEligible: eligible,
      ineligibleReason: ineligibleReason,
      isDefault: isDefault,
      overlapping: overlapping,
      clockInPreview: preview,
      operatingDay: operatingDay,
    );

IdentifyResponse _resp(
  List<TodayAttendanceItem> items, {
  String? defaultScheduleId,
}) =>
    IdentifyResponse(
      userId: 'u1',
      userName: 'Alice',
      todayStatus: items.isEmpty ? null : items.first.status,
      todayAttendances: items,
      defaultScheduleId: defaultScheduleId,
    );

void main() {
  group('formatShiftDuration — 숫자가 앞, 라벨은 l10n 이 뒤에 붙인다', () {
    test('60분 미만 → 분만', () {
      expect(formatShiftDuration(12), '12m');
      expect(formatShiftDuration(0), '0m');
    });

    test('60분 이상 → 시간 + 분', () {
      expect(formatShiftDuration(192), '3h 12m');
    });

    test('분이 0이면 시간만 (계약 §1.4)', () {
      expect(formatShiftDuration(120), '2h');
      expect(formatShiftDuration(60), '1h');
    });

    test('음수는 0 취급 (화면이 깨지면 안 된다)', () {
      expect(formatShiftDuration(-5), '0m');
    });
  });

  group('shiftPreviewOf — 서버 kind 를 그대로 옮긴다', () {
    test('late', () {
      final p = shiftPreviewOf(
        const ClockInPreview(kind: 'late', minutesLate: 192),
      );
      expect(p.kind, ShiftPreviewKind.late);
      expect(p.minutes, 192);
    });

    test('early + reason_required', () {
      final preview = const ClockInPreview(
        kind: 'early',
        minutesEarly: 18,
        reasonRequired: true,
      );
      final p = shiftPreviewOf(preview);
      expect(p.kind, ShiftPreviewKind.early);
      expect(p.minutes, 18);
      expect(preview.reasonRequired, isTrue);
    });

    test('on_time → 분은 0', () {
      final p = shiftPreviewOf(const ClockInPreview(kind: 'on_time'));
      expect(p.kind, ShiftPreviewKind.onTime);
      expect(p.minutes, 0);
    });

    test('null / 모르는 kind → unknown (줄 자체를 숨긴다)', () {
      expect(shiftPreviewOf(null).kind, ShiftPreviewKind.unknown);
      expect(
        shiftPreviewOf(const ClockInPreview(kind: 'something_new')).kind,
        ShiftPreviewKind.unknown,
      );
    });
  });

  group('pickDefaultShift — 서버가 정한 값을 그대로 쓴다 (§1.7)', () {
    test('default_schedule_id 와 같은 항목', () {
      final r = _resp([_item('s1'), _item('s2')], defaultScheduleId: 's2');
      expect(pickDefaultShift(r)!.scheduleId, 's2');
    });

    test('default_schedule_id 가 없으면 항목의 is_default', () {
      final r = _resp([_item('s1'), _item('s2', isDefault: true)]);
      expect(pickDefaultShift(r)!.scheduleId, 's2');
    });

    test('둘 다 없으면(구버전 서버) 고를 수 있는 첫 항목', () {
      final r = _resp([
        _item('s1',
            status: 'clocked_out',
            eligible: false,
            ineligibleReason: kIneligibleAlreadyCompleted),
        _item('s2'),
      ]);
      expect(pickDefaultShift(r)!.scheduleId, 's2');
    });

    test('고를 수 있는 게 하나도 없으면 첫 항목 (표시는 해야 한다)', () {
      final r = _resp([
        _item('s1',
            status: 'clocked_out',
            eligible: false,
            ineligibleReason: kIneligibleAlreadyCompleted),
      ]);
      expect(pickDefaultShift(r)!.scheduleId, 's1');
    });

    test('후보 없음 → null (워크인 경로)', () {
      expect(pickDefaultShift(_resp([])), isNull);
    });

    test('진행 중 shift 는 고를 수 없어도 기본이 될 수 있다 (D13)', () {
      // clock_in 이 있는 shift 는 clock-in 대상은 아니지만 "지금 화면의 주인공"이다.
      final r = _resp([
        _item('s1',
            status: 'working',
            eligible: false,
            ineligibleReason: kIneligibleAlreadyClockedIn),
        _item('s2'),
      ], defaultScheduleId: 's1');
      final picked = pickDefaultShift(r)!;
      expect(picked.scheduleId, 's1');
      expect(isShiftSelectable(picked), isFalse);
    });
  });

  group('canChooseShift — 후보 2개 이상일 때만 (D1)', () {
    test('0개/1개 → 선택지를 만들지 않는다', () {
      expect(canChooseShift(_resp([])), isFalse);
      expect(canChooseShift(_resp([_item('s1')])), isFalse);
    });

    test('2개 이상 → true', () {
      expect(canChooseShift(_resp([_item('s1'), _item('s2')])), isTrue);
    });

    test('완료된 shift 도 후보 수에 든다 (목록에 보이므로)', () {
      final r = _resp([
        _item('s1'),
        _item('s2',
            status: 'clocked_out',
            eligible: false,
            ineligibleReason: kIneligibleAlreadyCompleted),
      ]);
      expect(canChooseShift(r), isTrue);
    });
  });

  group('hasOverlappingShift — 배너 트리거 (§3.4)', () {
    test('overlapping 항목이 하나라도 있으면 true', () {
      expect(
        hasOverlappingShift(_resp([_item('s1'), _item('s2', overlapping: true)])),
        isTrue,
      );
    });

    test('없으면 false', () {
      expect(hasOverlappingShift(_resp([_item('s1')])), isFalse);
    });
  });

  group('isOverlappingClockInResponse — 트리거는 overlap.is_overlapping 하나뿐', () {
    test('true', () {
      expect(
        isOverlappingClockInResponse({
          'overlap': {'is_overlapping': true}
        }),
        isTrue,
      );
    });

    test('겹치지 않으면 서버가 overlap 키 자체를 안 넣는다', () {
      expect(isOverlappingClockInResponse({'id': 'a'}), isFalse);
      expect(isOverlappingClockInResponse(null), isFalse);
    });

    test('anomalies 문자열로는 판단하지 않는다 (표시 트리거는 overlap 하나)', () {
      expect(
        isOverlappingClockInResponse({
          'anomalies': ['overlapping_clock_in']
        }),
        isFalse,
      );
    });
  });

  group('isPreviewStale — 화면을 얼마나 오래 열어뒀나 (§1.2)', () {
    final t0 = DateTime(2026, 8, 13, 9, 0);

    test('3분 이내는 신선', () {
      expect(
        isPreviewStale(identifiedAt: t0, now: t0.add(const Duration(minutes: 3))),
        isFalse,
      );
    });

    test('3분 초과면 재조회', () {
      expect(
        isPreviewStale(
            identifiedAt: t0, now: t0.add(const Duration(minutes: 3, seconds: 1))),
        isTrue,
      );
    });

    test('시각을 모르면 재조회하지 않는다', () {
      expect(isPreviewStale(identifiedAt: null, now: t0), isFalse);
    });
  });

  group('openShiftWindowFromDetail', () {
    test('둘 다 있으면 시간대를 준다', () {
      final w = openShiftWindowFromDetail({
        'open_scheduled_start_display': '09:00',
        'open_scheduled_end_display': '13:00',
      });
      expect(w!.start, '09:00');
      expect(w.end, '13:00');
    });

    test('한쪽이라도 없으면 null (시간대 없이 일반 문구만)', () {
      expect(
        openShiftWindowFromDetail({'open_scheduled_start_display': '09:00'}),
        isNull,
      );
      expect(openShiftWindowFromDetail(null), isNull);
    });
  });

  group('isPreviousOperatingDay — "Yesterday" 배지 (D4)', () {
    test('영업일이 오늘과 다르면 true', () {
      expect(
        isPreviousOperatingDay(_item('s1', operatingDay: '2026-08-12'), '2026-08-13'),
        isTrue,
      );
    });

    test('같으면 false', () {
      expect(
        isPreviousOperatingDay(_item('s1', operatingDay: '2026-08-13'), '2026-08-13'),
        isFalse,
      );
    });

    test('모르면 배지를 안 붙인다 (틀린 배지보다 없는 편이 안전)', () {
      expect(isPreviousOperatingDay(_item('s1'), '2026-08-13'), isFalse);
      expect(
        isPreviousOperatingDay(_item('s1', operatingDay: '2026-08-12'), null),
        isFalse,
      );
    });
  });

  group('IdentifyResponse.fromJson — shift 계약 신규 필드 (§1.2)', () {
    test('최상위 default_schedule_id / server_time', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Alice',
        'today_status': 'late',
        'default_schedule_id': 's1',
        'server_time': '2026-08-13T20:05:11Z',
      });
      expect(r.defaultScheduleId, 's1');
      expect(r.serverTime, isNotNull);
    });

    test('항목별 신규 필드 + 프리뷰', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Alice',
        'today_status': 'no_show',
        'today_attendances': [
          {
            'schedule_id': 's1',
            'status': 'no_show',
            'attendance_id': 'a1',
            'operating_day': '2026-08-13',
            'clock_in': null,
            'clock_in_eligible': true,
            'ineligible_reason': null,
            'is_default': true,
            'overlapping': false,
            'clock_in_preview': {
              'kind': 'late',
              'minutes_early': 0,
              'minutes_late': 192,
              'reason_required': false,
            },
          },
        ],
      });
      final item = r.todayAttendances.single;
      expect(item.attendanceId, 'a1');
      expect(item.operatingDay, '2026-08-13');
      expect(item.clockIn, isNull);
      expect(item.isDefault, isTrue);
      expect(item.clockInEligible, isTrue);
      expect(item.clockInPreview!.kind, 'late');
      expect(item.clockInPreview!.minutesLate, 192);
    });

    test('clock_in_eligible 키가 없으면(구버전 서버) 고를 수 있는 것으로 본다', () {
      final r = IdentifyResponse.fromJson({
        'user_id': 'u1',
        'user_name': 'Alice',
        'today_status': 'upcoming',
        'today_attendances': [
          {'schedule_id': 's1', 'status': 'upcoming'},
        ],
      });
      expect(r.todayAttendances.single.clockInEligible, isTrue);
      expect(r.todayAttendances.single.clockInPreview, isNull);
    });

    test('withSelectedSchedule 은 default_schedule_id / server_time 을 잃지 않는다', () {
      final r = _resp([_item('s1'), _item('s2')], defaultScheduleId: 's1');
      final picked = r.withSelectedSchedule(r.todayAttendances[1]);
      expect(picked.selectedScheduleId, 's2');
      expect(picked.defaultScheduleId, 's1');
      expect(picked.selectedItem!.scheduleId, 's2');
    });
  });
}
