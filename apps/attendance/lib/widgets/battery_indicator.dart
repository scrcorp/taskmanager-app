/// 헤더용 배터리 칩.
///
/// 앱 고정(lock task) 상태에서는 안드로이드 상태바가 완전히 가려져 잔량도
/// 충전 여부도 볼 수 없다. 그래서 각 화면 헤더에 직접 띄운다.
/// 평소엔 조용한 회색 텍스트, 충전 중이거나 잔량이 낮을 때만 배경이 붙는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/battery_status.dart';
import '../providers/device_power_provider.dart';
import '../utils/battery_display.dart';

class BatteryIndicator extends ConsumerWidget {
  final double iconSize;
  final double fontSize;

  const BatteryIndicator({super.key, this.iconSize = 22, this.fontSize = 14});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(batteryStatusProvider).valueOrNull ?? BatteryStatus.unknown;
    // 안드로이드가 아니거나 아직 첫 브로드캐스트 전이면 자리를 차지하지 않는다.
    if (status.level == null && !status.powered) {
      return const SizedBox.shrink();
    }

    final t = AppL10n.of(context);
    final color = batteryColorFor(status);
    final highlight = batteryNeedsAttention(status);

    return Tooltip(
      message: '${batteryStateTextFor(t, status)} · ${batteryLabelFor(status)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? (status.charging ? AppColors.successBg : AppColors.dangerBg)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(batteryIconFor(status), size: iconSize, color: color),
            const SizedBox(width: 6),
            Text(
              batteryLabelFor(status),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
