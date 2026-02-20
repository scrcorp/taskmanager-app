import 'package:flutter/material.dart';
import '../config/theme.dart';

enum ModalType { error, warning, confirm, info }

class AppModal {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    ModalType type = ModalType.info,
    String? confirmText,
    String? cancelText,
  }) {
    final config = _modalConfig(type);
    final hasCancel = type == ModalType.confirm || cancelText != null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: config.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(config.icon, color: config.iconColor, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (hasCancel)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(cancelText ?? 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: config.iconColor,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(confirmText ?? 'Confirm'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config.iconColor,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(confirmText ?? 'OK'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static _ModalConfig _modalConfig(ModalType type) {
    switch (type) {
      case ModalType.error:
        return _ModalConfig(
          icon: Icons.error_rounded,
          iconColor: AppColors.danger,
          bgColor: AppColors.dangerBg,
        );
      case ModalType.warning:
        return _ModalConfig(
          icon: Icons.warning_rounded,
          iconColor: AppColors.warning,
          bgColor: AppColors.warningBg,
        );
      case ModalType.confirm:
        return _ModalConfig(
          icon: Icons.help_rounded,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentBg,
        );
      case ModalType.info:
        return _ModalConfig(
          icon: Icons.info_rounded,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentBg,
        );
    }
  }
}

class _ModalConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _ModalConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });
}
