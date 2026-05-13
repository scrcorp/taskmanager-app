/// Attendance Clock 액션 성공 화면
///
/// 체크 아이콘 + 환영 메시지 표시 후 3초 뒤 자동으로 Attendance shell 로 복귀.
/// "Go to Dashboard" 버튼으로 즉시 이동 가능.
///
/// Navigator.pop 을 연속 2회 호출하여 PIN 화면과 함께 닫는다
/// (main → pin → success 스택이므로 success pop → pin pop → main 복귀).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import 'attendance_main_screen.dart';

class AttendanceSuccessScreen extends StatefulWidget {
  final AttendanceAction action;
  final String userName;
  /// Clock-out 응답에서 받은 근무 분(net 우선). null 이면 표시 안 함.
  final int? workedMinutes;

  const AttendanceSuccessScreen({
    super.key,
    required this.action,
    required this.userName,
    this.workedMinutes,
  });

  @override
  State<AttendanceSuccessScreen> createState() =>
      _AttendanceSuccessScreenState();
}

class _AttendanceSuccessScreenState extends State<AttendanceSuccessScreen>
    with SingleTickerProviderStateMixin {
  late Timer _redirectTimer;
  int _countdown = 3;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  String _title(AppL10n t) {
    switch (widget.action) {
      case AttendanceAction.clockIn:
        return t.attSuccessClockIn;
      case AttendanceAction.clockOut:
        return t.attSuccessClockOut;
      case AttendanceAction.breakShortPaid:
        return t.attSuccessShortBreak;
      case AttendanceAction.breakLongUnpaid:
        return t.attSuccessLongBreak;
      case AttendanceAction.breakEnd:
        return t.attSuccessBreakEnded;
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _goToDashboard();
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

  /// Success + PIN 화면을 모두 pop하여 AttendanceMainScreen으로 복귀
  void _goToDashboard() {
    _redirectTimer.cancel();
    if (!mounted) return;
    // 스택: main → pin → success. 루트까지 pop (가장 아래 route까지 유지).
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 400,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(
                vertical: 48, horizontal: 32),
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
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFB8F0C8),
                          Color(0xFF7BE495),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success
                              .withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 44, color: Color(0xFF1B7A3D)),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _title(t),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontFamily: 'DMSans',
                    ),
                    children: [
                      TextSpan(text: t.attSuccessWelcomeBack),
                      if (widget.userName.isNotEmpty)
                        TextSpan(
                          text: t.attSuccessWelcomeBackName(widget.userName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        )
                      else
                        const TextSpan(text: '!'),
                    ],
                  ),
                ),
                if (widget.action == AttendanceAction.clockOut &&
                    widget.workedMinutes != null &&
                    widget.workedMinutes! > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          t.attSuccessWorkedTime(
                            widget.workedMinutes! ~/ 60,
                            widget.workedMinutes! % 60,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.attSuccessGreatJob,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _goToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2744),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.attSuccessGoToDashboard,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (3 - _countdown) / 3,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            AppColors.success),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.attSuccessRedirecting(_countdown),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
