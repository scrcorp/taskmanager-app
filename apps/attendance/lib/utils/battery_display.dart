/// 배터리 상태 → 아이콘/색/라벨 매핑 (순수 함수).
///
/// 위젯에서 분리해 둔 이유는 임계값(저전력 경고 등)을 테스트로 고정하기 위함.
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/battery_status.dart';

/// 주황 경고 기준(%). 이 아래는 [BatteryStatus.lowThreshold] 로 빨강.
const batteryWarningThreshold = 35;

/// 충전 중이면 번개, 아니면 잔량 단계별 막대 아이콘.
IconData batteryIconFor(BatteryStatus status) {
  if (status.charging) return Icons.battery_charging_full_rounded;
  if (status.full) return Icons.battery_full_rounded;
  // 케이블은 꽂혀 있는데 충전 중도 완충도 아닌 상태(급속충전 협상 중 등)도
  // 사용자 입장에선 "전원 연결됨"이므로 충전 아이콘으로 보여준다.
  if (status.plugged) return Icons.battery_charging_full_rounded;

  final level = status.level;
  if (level == null) return Icons.battery_unknown_rounded;
  if (level >= 95) return Icons.battery_full_rounded;
  if (level >= 80) return Icons.battery_6_bar_rounded;
  if (level >= 65) return Icons.battery_5_bar_rounded;
  if (level >= 50) return Icons.battery_4_bar_rounded;
  if (level >= 35) return Icons.battery_3_bar_rounded;
  if (level >= 20) return Icons.battery_2_bar_rounded;
  if (level >= 10) return Icons.battery_1_bar_rounded;
  return Icons.battery_alert_rounded;
}

/// 전원 연결 = 초록, 저전력 = 빨강, 그 위 여유 없음 = 주황, 나머지 = 회색.
Color batteryColorFor(BatteryStatus status) {
  if (status.powered) return AppColors.success;
  final level = status.level;
  if (level == null) return AppColors.textMuted;
  if (level <= BatteryStatus.lowThreshold) return AppColors.danger;
  if (level <= batteryWarningThreshold) return AppColors.warning;
  return AppColors.textSecondary;
}

/// 칩에 표시할 잔량 문자열. 잔량을 모르면 대시.
String batteryLabelFor(BatteryStatus status) {
  final level = status.level;
  if (level == null) return '—';
  return '$level%';
}

/// 배경을 깔아 눈에 띄게 할지 여부 — 충전 중이거나 저전력일 때만.
/// 평상시엔 헤더에서 조용히 있어야 하므로 배경 없음.
bool batteryNeedsAttention(BatteryStatus status) =>
    status.charging || status.low;

/// 상태 문구. 우선순위: 충전 중 > 완충 > 연결됨 > 저전력 > 배터리 구동.
String batteryStateTextFor(AppL10n t, BatteryStatus status) {
  if (status.charging) return t.attBatteryCharging;
  if (status.full) return t.attBatteryFull;
  if (status.plugged) return t.attBatteryPluggedIn;
  if (status.low) return t.attBatteryLow;
  return t.attBatteryOnBattery;
}
