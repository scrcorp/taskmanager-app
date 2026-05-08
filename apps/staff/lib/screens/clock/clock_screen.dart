/// 출퇴근(Clock In/Out) 화면 — 미구현 플레이스홀더
///
/// 추후 GPS/QR 기반 출퇴근 기록 기능이 구현될 예정.
/// 현재는 "Coming soon" 메시지만 표시.
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';

/// 출퇴근 화면 — 미구현 상태
class ClockScreen extends StatelessWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.access_time_outlined, size: 32, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            t.clockTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            t.commonComingSoon,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            t.clockSubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
