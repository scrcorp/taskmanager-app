/// HTMA — **영업일이 넘어간 뒤, 어제 영업일의 미퇴근 근무로 퇴근할 수 있는가.**
///
/// 재현 조건 (실제 매장 설정 그대로):
///   1. 매장 영업일 경계 `day_start = 04:00`
///   2. 지금 = 8/18 05:00  → 오늘 영업일 = **8/18** (05:00 ≥ 04:00)
///   3. 근무 = 영업일 **8/17** 의 새벽조, 실제 시각 8/18 01:00 ~ 06:00
///      (01:00 은 경계 이전이라 달력일이 영업일+1일 = 8/18 이다)
///   4. HTMA 목록은 영업일 기준이라 화면은 "8/18" 을 보고 있다
///   5. 직원이 PIN 을 누른다
///
/// 걱정했던 것: 앱이 "오늘(8/18) 것만" 들고 있어서 8/17 라벨 근무가 안 보이고,
/// 그러면 Clock Out 버튼 자체가 안 떠서 키오스크에서 퇴근할 방법이 사라진다.
///
/// 여기서 고정하는 사실:
///   - 앱의 액션 분기는 **`today_status` 하나**로 돈다. 날짜로 다시 거르지 않는다.
///   - `operating_day` 는 **필터가 아니라 라벨**이다 — "Yesterday" 배지를 붙이는 데만 쓴다.
///   - 따라서 서버가 어제 라벨의 진행 중 근무를 실어 주면(서버 쪽 계약은
///     `tests/integration/api/attendance/test_shift_pick_and_overlap.py` 가 고정한다)
///     앱은 그대로 Clock Out 을 연다.
library;

import 'package:attendance/models/attendance_action.dart';
import 'package:attendance/models/identify_response.dart';
import 'package:attendance/utils/attendance_action_policy.dart';
import 'package:attendance/utils/shift_pick_logic.dart';
import 'package:attendance/widgets/action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

/// 오늘 영업일(화면이 보고 있는 날). 경계 04:00 이라 8/18 05:00 의 영업일은 8/18.
const String kTodayOperatingDay = '2026-08-18';

/// 어제 영업일(8/17)의 새벽조 — 달력상으로는 8/18 01:00~06:00 이다.
TodayAttendanceItem _yesterdayNightShift() => TodayAttendanceItem(
      scheduleId: 'sc-night',
      status: 'working',
      operatingDay: '2026-08-17',
      scheduledStart: DateTime.utc(2026, 8, 18, 1, 0),
      scheduledEnd: DateTime.utc(2026, 8, 18, 6, 0),
      scheduledStartDisplay: '01:00',
      scheduledEndDisplay: '06:00',
      clockIn: DateTime.utc(2026, 8, 18, 1, 2),
      clockInDisplay: '01:02',
      attendanceId: 'att-night',
      clockInEligible: false,
      ineligibleReason: 'already_clocked_in',
      isDefault: true,
    );

IdentifyResponse _identified() => IdentifyResponse(
      userId: 'u1',
      userName: 'Marcus Lee',
      todayStatus: 'working',
      todayAttendances: [_yesterdayNightShift()],
      selectedScheduleId: 'sc-night',
    );

Future<void> _useTabletSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

bool _isTileEnabled(WidgetTester tester, String label) {
  final tile = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
  return tester.widget<InkWell>(tile).onTap != null;
}

void main() {
  group('영업일이 넘어간 뒤의 어제 근무', () {
    test('액션 분기는 today_status 만 본다 — 날짜로 거르지 않는다', () {
      expect(
        isActionAllowed(todayStatus: 'working', action: AttendanceAction.clockOut),
        isTrue,
      );
      // 목록이 비어 있어도(= 서버가 아무것도 안 줬을 때만) Clock Out 이 막힌다.
      expect(
        isActionAllowed(todayStatus: null, action: AttendanceAction.clockOut),
        isFalse,
      );
    });

    test('operating_day 는 필터가 아니라 라벨이다', () {
      final item = _yesterdayNightShift();
      // 오늘(8/18)과 다르므로 "어제 것" 으로 **표시**된다 — 목록에서 빠지는 게 아니다.
      expect(isPreviousOperatingDay(item, kTodayOperatingDay), isTrue);
      expect(isPreviousOperatingDay(item, '2026-08-17'), isFalse);
    });

    testWidgets('PIN 입력 후 Clock Out 이 실제로 눌리는 상태로 뜬다', (tester) async {
      await _useTabletSurface(tester);
      AttendanceAction? picked;
      await tester.pumpWidget(wrapForTest(ActionSheet(
        user: _identified(),
        onPick: (a) => picked = a,
        onCancel: () {},
        todayOperatingDay: kTodayOperatingDay, // 화면은 8/18 을 보고 있다
      )));

      expect(_isTileEnabled(tester, 'Clock Out'), isTrue,
          reason: '어제 영업일 근무라도 진행 중이면 퇴근할 수 있어야 한다');
      // 이미 찍었으므로 Clock In 은 닫혀 있어야 한다 — 둘 다 열리면 이중 출근이 난다.
      expect(_isTileEnabled(tester, 'Clock In'), isFalse);

      await tester.tap(find.text('Clock Out'));
      await tester.pump();
      expect(picked, AttendanceAction.clockOut);
    });
  });
}
