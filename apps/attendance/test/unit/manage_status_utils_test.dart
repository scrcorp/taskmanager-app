/// Unit tests — manage_status_utils (Issue 10: state/anomaly/soon 분류, pure logic).

import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:attendance/utils/manage_status_utils.dart';
import 'package:attendance/utils/staff_status_utils.dart' show StaffSection;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sectionForManageState', () {
    test('working/breaking → clockedIn', () {
      expect(sectionForManageState('working'), StaffSection.clockedIn);
      expect(sectionForManageState('breaking'), StaffSection.clockedIn);
    });
    test('upcoming → notClockedIn', () {
      expect(sectionForManageState('upcoming'), StaffSection.notClockedIn);
    });
    test('done → completed', () {
      expect(sectionForManageState('done'), StaffSection.completed);
    });
    test('unknown → other', () {
      expect(sectionForManageState('cancelled'), StaffSection.other);
    });
  });

  group('isManageSoon', () {
    final now = DateTime(2026, 5, 29, 15, 22);

    test('upcoming + 시작 28분 후 → soon', () {
      expect(isManageSoon('upcoming', const [], '15:50', now), isTrue);
    });
    test('upcoming + 시작 2시간 후 → soon 아님', () {
      expect(isManageSoon('upcoming', const [], '17:30', now), isFalse);
    });
    test('working 이면 soon 아님', () {
      expect(isManageSoon('working', const [], '15:50', now), isFalse);
    });
    test('late anomaly 면 soon 아님', () {
      expect(isManageSoon('upcoming', const ['late'], '15:50', now), isFalse);
    });
    test('이미 시작 시각 지났으면 soon 아님', () {
      expect(isManageSoon('upcoming', const [], '14:00', now), isFalse);
    });

    // startAt(벽시계 datetime) 분기 — 자정 넘김 정확
    test('startAt 우선: 28분 후 시작 → soon', () {
      expect(
        isManageSoon('upcoming', const [], null, now,
            startAt: DateTime(2026, 5, 29, 15, 50)),
        isTrue,
      );
    });
    test('startAt 우선: HHmm은 임박해 보여도 startAt이 익일이면 soon 아님', () {
      // startHHmm "15:50"만 보면 soon이지만, 실제 startAt은 다음날 → 아님
      final nowNight = DateTime(2026, 5, 29, 23, 40);
      expect(
        isManageSoon('upcoming', const [], '15:50', nowNight,
            startAt: DateTime(2026, 5, 30, 15, 50)),
        isFalse,
      );
    });
    test('startAt 우선: 자정 직후 시작(익일 00:10)을 밤 23:50에 → soon', () {
      final nowNight = DateTime(2026, 5, 29, 23, 50);
      expect(
        isManageSoon('upcoming', const [], null, nowNight,
            startAt: DateTime(2026, 5, 30, 0, 10)),
        isTrue,
      );
    });
  });

  group('labels', () {
    test('manageStateLabel', () {
      expect(manageStateLabel('breaking'), 'Breaking');
      expect(manageStateLabel('done'), 'Done');
    });
    test('manageAnomalyLabel', () {
      expect(manageAnomalyLabel('no_show'), 'No-show');
      expect(manageAnomalyLabel('no_break'), 'No Break');
    });
  });

  group('AdminScheduleRow.fromJson — state/anomalies/breaks', () {
    test('새 필드 파싱', () {
      final row = AdminScheduleRow.fromJson({
        'schedule_id': 's1',
        'user_id': 'u1',
        'user_name': 'Priya Nair',
        'status': 'confirmed',
        'state': 'breaking',
        'anomalies': ['late', 'overtime'],
        'breaks': [
          {'type': 'paid_10min', 'start': '15:10', 'end': null},
          {'type': 'unpaid_meal', 'start': '12:30', 'end': '13:02'},
        ],
      });
      expect(row.state, 'breaking');
      expect(row.anomalies, ['late', 'overtime']);
      expect(row.breaks.length, 2);
      expect(row.breaks[0].type, 'paid_10min');
      expect(row.breaks[0].inProgress, isTrue);
      expect(row.breaks[1].end, '13:02');
      expect(row.breaks[1].inProgress, isFalse);
    });

    test('새 필드 없으면 기본값 (state=upcoming, 빈 리스트)', () {
      final row = AdminScheduleRow.fromJson({
        'schedule_id': 's1',
        'user_id': 'u1',
        'user_name': 'Alice',
        'status': 'confirmed',
      });
      expect(row.state, 'upcoming');
      expect(row.anomalies, isEmpty);
      expect(row.breaks, isEmpty);
    });
  });
}
