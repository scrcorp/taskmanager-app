/// 토스트 알림 위젯 — 애니메이션 포함
///
/// 우측에서 슬라이드+페이드 인 되며 표시되고
/// 지정된 duration 후 자동으로 슬라이드+페이드 아웃.
/// success(녹)/error(빨)/warning(노)/info(파) 4가지 타입.
/// X 버튼으로 수동 닫기도 가능.
/// ToastManager에 의해 Overlay에 삽입되어 사용됨.
import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 토스트 타입 열거형
enum ToastType { success, error, warning, info }

/// 토스트 알림 위젯 — 슬라이드+페이드 애니메이션
class AppToast extends StatefulWidget {
  final String message;
  final ToastType type;
  /// 소멸 시 ToastManager에 알리는 콜백
  final VoidCallback onDismiss;
  /// 자동 소멸까지의 대기 시간
  final Duration duration;

  const AppToast({
    super.key,
    required this.message,
    this.type = ToastType.info,
    required this.onDismiss,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  /// 우측에서 슬라이드 인 애니메이션
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    // 지정 시간 후 자동 소멸
    _autoTimer = Timer(widget.duration, _dismiss);
  }

  /// 소멸 애니메이션 후 콜백 호출
  void _dismiss() {
    _autoTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _typeConfig;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 340,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: config.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: config.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(config.icon, color: config.iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _dismiss,
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 타입별 아이콘/색상 설정
  _ToastConfig get _typeConfig {
    switch (widget.type) {
      case ToastType.success:
        return _ToastConfig(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          bgColor: AppColors.successBg,
          borderColor: AppColors.success.withValues(alpha: 0.3),
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.error_rounded,
          iconColor: AppColors.danger,
          bgColor: AppColors.dangerBg,
          borderColor: AppColors.danger.withValues(alpha: 0.3),
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: Icons.warning_rounded,
          iconColor: AppColors.warning,
          bgColor: AppColors.warningBg,
          borderColor: AppColors.warning.withValues(alpha: 0.3),
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_rounded,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentBg,
          borderColor: AppColors.accent.withValues(alpha: 0.3),
        );
    }
  }
}

/// 토스트 타입별 스타일 설정 데이터
class _ToastConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _ToastConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });
}
