/// OverlapConfirmDialog — 다른 shift 가 열려 있는데 또 찍으려 할 때의 확인 (D15/§3.2).
///
/// 서버는 `overlapping_clock_in_confirmation_required` 400 을 주고, 사용자가 확인하면
/// **같은 요청에 `allow_overlap: true` 만 붙여 재전송**한다.
/// `early_clock_in_reason_required` 와 동일한 재시도 형태라 상태기계에 새 개념이 없다.
///
/// 확인 없이 통과시키면 안 되는 이유: 지금 이 가드 하나가 키오스크 더블탭·네트워크
/// 재시도로 인한 중복 row 까지 함께 막고 있다.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';

class OverlapConfirmDialog extends StatelessWidget {
  /// 아직 열려 있는 shift 의 시간대 (서버 detail). 없으면 일반 문구만 보여준다.
  final String? openStartDisplay;
  final String? openEndDisplay;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const OverlapConfirmDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.openStartDisplay,
    this.openEndDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final hasWindow = openStartDisplay != null &&
        openStartDisplay!.isNotEmpty &&
        openEndDisplay != null &&
        openEndDisplay!.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.warningBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 36,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.pfOverlapConfirmTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.pfOverlapConfirmBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (hasWindow) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.pfOverlapConfirmShift(
                        openStartDisplay!,
                        openEndDisplay!,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                              color: AppColors.border,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            t.pfOverlapConfirmNo,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            t.pfOverlapConfirmYes,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
