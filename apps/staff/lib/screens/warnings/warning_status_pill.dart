/// 경고 상태 pill — staff 기준 두 상태 (acknowledge 는 자동).
///
///   미서명 → "Signature required" (amber: warningBg / warning)
///   서명됨 → "Signed" (+ 체크, green: successBg / success)
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';

class WarningStatusPill extends StatelessWidget {
  final bool signed;

  const WarningStatusPill({super.key, required this.signed});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final fg = signed ? AppColors.success : AppColors.warning;
    final bg = signed ? AppColors.successBg : AppColors.warningBg;
    final icon = signed ? Icons.check_rounded : Icons.warning_amber_rounded;
    final label = signed ? t.warningStatusSigned : t.warningStatusUnsigned;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
