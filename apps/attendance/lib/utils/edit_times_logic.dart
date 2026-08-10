/// Edit Times 모달의 순수 로직 — 어떤 시각을 고칠 수 있고, 무엇이 바뀌었는지.
///
/// 이 화면이 생긴 이유: clock-in 시각 하나를 고치려고 Undo Clock-in → 재입력을
/// 하면 break 기록과 anomaly 가 함께 정리돼 버린다. 그래서 여기서는 **상태 전이를
/// 일절 하지 않고** 시각만 모아서 한 번에 보낸다.
///
/// 시각 순서/겹침 검증은 **서버에 맡긴다.** 영업일 경계(마감조 02:00 퇴근 등)를
/// 알아야 "clock_out < clock_in" 인지 판정할 수 있는데 클라이언트는 store 의
/// day_start 를 모른다. 여기서 어설프게 막으면 정상 입력을 거부하게 된다.

import '../providers/attendance_manage_provider.dart';
import 'schedule_edit_logic.dart' show hhmmToMinutes, minutesToHHmm;

/// 고칠 수 있는 시각 한 칸의 종류.
enum TimeTargetKind { clockIn, clockOut, breakStart, breakEnd }

/// 모달의 편집 단위 — 칩 하나 = 휠 하나.
class TimeTarget {
  final TimeTargetKind kind;

  /// break 관련일 때만 채워진다.
  final String? breakId;

  /// 칩에 쓰는 짧은 라벨 ("Clock In", "Meal start" …).
  final String label;

  /// 서버에 기록돼 있는 원래 값 (분). 변경 여부 판정 기준.
  final int originalMinutes;

  const TimeTarget({
    required this.kind,
    required this.label,
    required this.originalMinutes,
    this.breakId,
  });

  /// 상태 맵의 키 — break 는 세션마다 따로여야 하므로 id 를 섞는다.
  String get key => breakId == null ? kind.name : '${kind.name}:$breakId';
}

/// break 종류의 짧은 라벨 ("Meal" / "10-min").
String shortBreakLabel(String breakType) {
  if (breakType == 'unpaid_meal' || breakType == 'unpaid_long') return 'Meal';
  if (breakType == 'paid_10min' || breakType == 'paid_short') return '10-min';
  return 'Break';
}

/// 이 row 에서 시각 보정이 가능한 칸들. 기록이 없는 칸은 아예 만들지 않는다
/// (없는 시각을 "고치는" 건 시각 보정이 아니라 상태 전이다).
///
/// 진행 중 break 는 시작만 고칠 수 있다 — 종료 시각이 아직 없기 때문.
List<TimeTarget> buildTimeTargets(AdminScheduleRow row) {
  final out = <TimeTarget>[];

  final clockIn = hhmmToMinutes(row.clockInDisplay);
  if (clockIn != null) {
    out.add(TimeTarget(
      kind: TimeTargetKind.clockIn,
      label: 'Clock In',
      originalMinutes: clockIn,
    ));
  }
  final clockOut = hhmmToMinutes(row.clockOutDisplay);
  if (clockOut != null) {
    out.add(TimeTarget(
      kind: TimeTargetKind.clockOut,
      label: 'Clock Out',
      originalMinutes: clockOut,
    ));
  }

  for (final b in row.breaks) {
    if (!b.editable) continue; // id 없는 구버전 응답 — 지목할 방법이 없다
    final short = shortBreakLabel(b.type);
    final start = hhmmToMinutes(b.start);
    if (start != null) {
      out.add(TimeTarget(
        kind: TimeTargetKind.breakStart,
        breakId: b.id,
        label: '$short start',
        originalMinutes: start,
      ));
    }
    final end = hhmmToMinutes(b.end);
    if (end != null) {
      out.add(TimeTarget(
        kind: TimeTargetKind.breakEnd,
        breakId: b.id,
        label: '$short end',
        originalMinutes: end,
      ));
    }
  }
  return out;
}

/// 서버로 보낼 값들. 바뀐 칸만 담는다 — 안 바뀐 값을 같이 보내면 이력에
/// "고쳤다"고 남지는 않지만(서버가 before==after 를 버린다) 보낼 이유도 없다.
class EditTimesPayload {
  final String? clockInHHmm;
  final String? clockOutHHmm;

  /// [{break_id, start_hhmm?, end_hhmm?}] — 서버 스키마 그대로.
  final List<Map<String, String>> breaks;

  const EditTimesPayload({
    this.clockInHHmm,
    this.clockOutHHmm,
    this.breaks = const [],
  });

  bool get isEmpty =>
      clockInHHmm == null && clockOutHHmm == null && breaks.isEmpty;
}

/// [targets] 와 현재 편집값 [values] (key → 분) 를 비교해 변경분만 payload 로.
EditTimesPayload buildEditTimesPayload(
  List<TimeTarget> targets,
  Map<String, int> values,
) {
  String? clockIn;
  String? clockOut;
  // 한 break 의 start/end 가 함께 바뀌면 한 항목으로 합쳐야 한다.
  final byBreak = <String, Map<String, String>>{};

  for (final t in targets) {
    final v = values[t.key];
    if (v == null || v == t.originalMinutes) continue;
    final hhmm = minutesToHHmm(v);
    switch (t.kind) {
      case TimeTargetKind.clockIn:
        clockIn = hhmm;
        break;
      case TimeTargetKind.clockOut:
        clockOut = hhmm;
        break;
      case TimeTargetKind.breakStart:
        (byBreak[t.breakId!] ??= {'break_id': t.breakId!})['start_hhmm'] = hhmm;
        break;
      case TimeTargetKind.breakEnd:
        (byBreak[t.breakId!] ??= {'break_id': t.breakId!})['end_hhmm'] = hhmm;
        break;
    }
  }

  return EditTimesPayload(
    clockInHHmm: clockIn,
    clockOutHHmm: clockOut,
    breaks: byBreak.values.toList(),
  );
}

/// Save 활성 여부 — 바뀐 게 있고 사유가 있어야 한다.
/// 시각 보정은 급여에 직접 닿는 변경이라 사유를 선택으로 두지 않는다.
bool canSubmitEditTimes(EditTimesPayload payload, String reason) {
  return !payload.isEmpty && reason.trim().isNotEmpty;
}

/// 칩 아래에 띄우는 "원래 값 대비" 안내 ("7m earlier than recorded").
/// 변경이 없으면 null.
String? changeHint(int originalMinutes, int currentMinutes) {
  final d = currentMinutes - originalMinutes;
  if (d == 0) return null;
  final abs = d.abs();
  final label = abs >= 60 ? '${abs ~/ 60}h ${abs % 60}m' : '${abs}m';
  return '$label ${d < 0 ? 'earlier' : 'later'} than recorded';
}
