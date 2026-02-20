import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

enum ToastType { success, error, warning, info }

class AppToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
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
    _autoTimer = Timer(widget.duration, _dismiss);
  }

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
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _dismiss,
                child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
