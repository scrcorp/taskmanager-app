/// 경고 상태 pill — 서명 방식(digital/wet)을 인지한다.
///
///   digital 미서명 → "Signature required" (amber: warningBg / warning)
///   digital 서명됨 → "Signed" (+ 체크, green: successBg / success)
///   wet 미업로드   → "Sign in person" (중립: bg / textSecondary, 직원이 앱서 할 게 없음)
///   wet 업로드됨   → "Signed" (+ 체크, green)
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/warning.dart';

class WarningStatusPill extends StatelessWidget {
  final Warning warning;

  const WarningStatusPill({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    final Color fg;
    final Color bg;
    final IconData icon;
    final String label;

    if (warning.isWet) {
      if (warning.signedPdfPresent) {
        // wet 업로드 완료 = 서명 완료(녹색).
        fg = AppColors.success;
        bg = AppColors.successBg;
        icon = Icons.check_rounded;
        label = t.warningStatusSigned;
      } else {
        // wet 미업로드 = 직원이 앱에서 할 게 없음 → 중립 안내.
        fg = AppColors.textSecondary;
        bg = AppColors.bg;
        icon = Icons.draw_outlined;
        label = t.warningStatusSignInPerson;
      }
    } else if (warning.isSigned) {
      fg = AppColors.success;
      bg = AppColors.successBg;
      icon = Icons.check_rounded;
      label = t.warningStatusSigned;
    } else {
      fg = AppColors.warning;
      bg = AppColors.warningBg;
      icon = Icons.warning_amber_rounded;
      label = t.warningStatusUnsigned;
    }

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
