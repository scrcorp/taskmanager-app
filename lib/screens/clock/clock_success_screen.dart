/// Clock In/Out 성공 화면 — 완료 확인 + 자동 리다이렉트
///
/// 체크 아이콘과 환영 메시지 표시 후 3초 뒤 자동으로 Clock 대시보드로 복귀.
/// "Go to Dashboard" 버튼으로 즉시 이동도 가능.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import 'clock_screen.dart';

class ClockSuccessScreen extends StatefulWidget {
  final ClockAction action;
  final String userName;

  const ClockSuccessScreen({
    super.key,
    required this.action,
    required this.userName,
  });

  @override
  State<ClockSuccessScreen> createState() => _ClockSuccessScreenState();
}

class _ClockSuccessScreenState extends State<ClockSuccessScreen>
    with SingleTickerProviderStateMixin {
  late Timer _redirectTimer;
  int _countdown = 3;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  String get _title {
    switch (widget.action) {
      case ClockAction.clockIn:
        return 'Clock In Successful';
      case ClockAction.clockOut:
        return 'Clock Out Successful';
      case ClockAction.takeBreak:
        return 'Break Started';
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();

    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) context.go('/clock');
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    _redirectTimer.cancel();
    context.go('/clock');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 체크 아이콘 ──
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB8F0C8), Color(0xFF7BE495)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, size: 44, color: Color(0xFF1B7A3D)),
                ),
              ),
              const SizedBox(height: 28),
              // ── 타이틀 ──
              Text(
                _title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              // ── 환영 메시지 ──
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'DMSans'),
                  children: [
                    const TextSpan(text: 'Welcome back, '),
                    TextSpan(
                      text: '${widget.userName}!',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ── Go to Dashboard 버튼 ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goToDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2744),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Go to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── 프로그레스 바 ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (3 - _countdown) / 3,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              const SizedBox(height: 8),
              // ── 카운트다운 텍스트 ──
              Text(
                'REDIRECTING IN $_countdown SECONDS',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
