/// 근무 가용성(Work Availability) 데이터 모델
///
/// 매니저/슈퍼바이저가 설정한 직원의 주간 가용성. 앱에서는 조회 전용(read-only).
/// 요일은 항상 일요일 시작(0=Sun .. 6=Sat).
/// 하루의 상태는 3가지: off(비근무) / range(특정 시간대) / full(종일).

/// 하루 가용성 상태
enum AvailabilityState { off, range, full }

/// state 문자열 → enum 변환 (알 수 없는 값은 off로 방어적 처리)
AvailabilityState _parseState(String? raw) {
  switch (raw) {
    case 'range':
      return AvailabilityState.range;
    case 'full':
      return AvailabilityState.full;
    default:
      return AvailabilityState.off;
  }
}

/// enum → 서버 state 문자열 (PUT 페이로드용)
String availabilityStateToString(AvailabilityState state) {
  switch (state) {
    case AvailabilityState.range:
      return 'range';
    case AvailabilityState.full:
      return 'full';
    case AvailabilityState.off:
      return 'off';
  }
}

/// 하루치 가용성
class AvailabilityDay {
  /// 0=Sun .. 6=Sat
  final int dayOfWeek;
  final AvailabilityState state;
  /// "HH:MM" — state가 range일 때만 존재
  final String? startTime;
  /// "HH:MM" — state가 range일 때만 존재
  final String? endTime;

  const AvailabilityDay({
    required this.dayOfWeek,
    required this.state,
    this.startTime,
    this.endTime,
  });

  /// 서버 JSON → AvailabilityDay
  factory AvailabilityDay.fromJson(Map<String, dynamic> json) {
    return AvailabilityDay(
      dayOfWeek: json['day_of_week'] as int,
      state: _parseState(json['state'] as String?),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
    );
  }

  /// AvailabilityDay → 서버 JSON (PUT /app/my/availability 페이로드).
  /// range 가 아니면 start/end 는 null 로 보낸다.
  Map<String, dynamic> toJson() {
    final isRange = state == AvailabilityState.range;
    return {
      'day_of_week': dayOfWeek,
      'state': availabilityStateToString(state),
      'start_time': isRange ? startTime : null,
      'end_time': isRange ? endTime : null,
    };
  }
}

/// 내 주간 가용성 (7일 + 편집 가능 여부 + 마지막 수정 시각)
class MyAvailability {
  /// 항상 7개, 인덱스 = 요일(0=Sun .. 6=Sat)
  final List<AvailabilityDay> days;
  /// 직원 본인이 편집 가능한지 (앱 read-only 화면에서는 사용하지 않지만 서버 계약 유지)
  final bool canEdit;
  final DateTime? updatedAt;

  const MyAvailability({
    required this.days,
    required this.canEdit,
    this.updatedAt,
  });

  /// 가용성이 한 번이라도 저장된 적 있는지.
  /// 서버는 저장 이력이 없으면 updated_at 을 null 로 준다(빈 주간 = 미설정).
  bool get isSet => updatedAt != null;

  /// 서버 JSON → MyAvailability
  ///
  /// 응답의 days 배열에서 누락된 요일은 off로 채워 항상 7개(Sun→Sat)를 보장한다.
  /// (서버 계약: 목록에서 빠진 요일 = off)
  factory MyAvailability.fromJson(Map<String, dynamic> json) {
    final raw = (json['days'] as List<dynamic>? ?? [])
        .map((e) => AvailabilityDay.fromJson(e as Map<String, dynamic>))
        .toList();
    final byDay = {for (final d in raw) d.dayOfWeek: d};
    final full = List<AvailabilityDay>.generate(
      7,
      (i) =>
          byDay[i] ??
          AvailabilityDay(dayOfWeek: i, state: AvailabilityState.off),
    );
    return MyAvailability(
      days: full,
      canEdit: json['can_edit'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
