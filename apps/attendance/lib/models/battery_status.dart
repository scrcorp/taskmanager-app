/// 태블릿 배터리 상태 스냅샷.
///
/// 네이티브(MainActivity)의 ACTION_BATTERY_CHANGED 브로드캐스트를 그대로 옮긴 값.
/// 앱 고정(lock task) 상태에서는 시스템 상태바가 가려져 충전 여부를 알 수 없어
/// 헤더에 직접 표시하기 위해 쓴다.
class BatteryStatus {
  /// 잔량 0~100. 알 수 없으면 null.
  final int? level;

  /// 실제로 충전 중(전류가 들어오는 중). 완충되면 false 로 바뀐다.
  final bool charging;

  /// 완충 상태.
  final bool full;

  /// 케이블이 꽂혀 있음. 완충이라 [charging] 이 false 여도 true 다.
  final bool plugged;

  const BatteryStatus({
    this.level,
    this.charging = false,
    this.full = false,
    this.plugged = false,
  });

  /// 아직 첫 브로드캐스트를 못 받은 상태.
  static const unknown = BatteryStatus();

  /// 네이티브 EventChannel 이 보내는 map 을 파싱. 값이 빠지거나 타입이 달라도
  /// 던지지 않는다 — 배터리 표시 하나 때문에 헤더가 깨지면 안 되므로.
  factory BatteryStatus.fromMap(Map<Object?, Object?> map) {
    final rawLevel = map['level'];
    final level = rawLevel is int ? rawLevel : null;
    return BatteryStatus(
      // 네이티브는 알 수 없을 때 -1 을 보낸다. 범위를 벗어난 값도 unknown 처리.
      level: (level != null && level >= 0 && level <= 100) ? level : null,
      charging: map['charging'] == true,
      full: map['full'] == true,
      plugged: map['plugged'] == true,
    );
  }

  /// 전원이 연결된 상태 — 충전 중이거나 완충이거나 케이블만 꽂힌 경우 모두 포함.
  bool get powered => charging || full || plugged;

  /// 배터리로만 구동 중이면서 잔량이 얼마 안 남은 상태.
  bool get low => !powered && level != null && level! <= lowThreshold;

  /// 저전력 경고 기준(%).
  static const lowThreshold = 20;

  @override
  bool operator ==(Object other) =>
      other is BatteryStatus &&
      other.level == level &&
      other.charging == charging &&
      other.full == full &&
      other.plugged == plugged;

  @override
  int get hashCode => Object.hash(level, charging, full, plugged);

  @override
  String toString() =>
      'BatteryStatus(level: $level, charging: $charging, full: $full, '
      'plugged: $plugged)';
}
