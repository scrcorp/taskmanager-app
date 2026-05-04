/// 앱 모달 다이얼로그 — 공통 알림/확인 팝업
///
/// 4가지 타입: error(빨강), warning(노랑), confirm(파랑+취소), info(파랑)
/// confirm 타입만 취소 버튼이 함께 표시됨.
/// `AppModal.show()` 정적 메서드로 호출하며 bool? 반환
/// (confirm: true=확인/false=취소, 나머지: true=OK).
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 모달 타입 열거형
enum ModalType { error, warning, confirm, info, success }

/// 모달 다이얼로그 유틸리티 클래스
class AppModal {
  /// 모달 표시 — 타입에 따른 아이콘/색상 자동 적용
  ///
  /// [type]: 모달 스타일 결정 (아이콘, 색상)
  /// [confirmText]: 확인 버튼 라벨 (기본: OK/Confirm)
  /// [cancelText]: 취소 버튼 라벨 (기본: Cancel, confirm 타입에서만 표시)
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
                // 타입별 아이콘
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // 취소+확인 또는 확인만
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
                            foregroundColor: config.buttonFgColor,
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
                        foregroundColor: config.buttonFgColor,
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

  /// 타입별 아이콘/색상 설정
  static _ModalConfig _modalConfig(ModalType type) {
    switch (type) {
      case ModalType.error:
        return _ModalConfig(
          icon: Icons.error_rounded,
          iconColor: AppColors.danger,
          bgColor: AppColors.dangerBg,
          buttonFgColor: AppColors.white,
        );
      case ModalType.warning:
        return _ModalConfig(
          icon: Icons.warning_rounded,
          iconColor: AppColors.warning,
          bgColor: AppColors.warningBg,
          buttonFgColor: AppColors.white,
        );
      case ModalType.confirm:
        return _ModalConfig(
          icon: Icons.help_rounded,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentBg,
          buttonFgColor: AppColors.white,
        );
      case ModalType.info:
        return _ModalConfig(
          icon: Icons.info_rounded,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentBg,
          buttonFgColor: AppColors.white,
        );
      case ModalType.success:
        return _ModalConfig(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          bgColor: AppColors.successBg,
          buttonFgColor: AppColors.white,
        );
    }
  }
}

/// 모달 타입별 스타일 설정 데이터
class _ModalConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color buttonFgColor;

  const _ModalConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.buttonFgColor,
  });
}
