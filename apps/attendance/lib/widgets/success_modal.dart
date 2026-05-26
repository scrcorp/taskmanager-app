/// SuccessModal — clock action 성공 후 친근한 멘트 노출.
///
/// mockup 결정 (2026-05-22):
///   - 체크 아이콘 + 액션별 타이틀 + 친근한 한 줄 멘트 ("{name}!" 보간)
///   - OK 버튼 + 5초 자동 닫힘
///   - autoClose=false 시 자동 닫힘 비활성 (gallery 데모용)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/attendance_action.dart';

({String title, String greeting}) _localizedSuccess(
  AppL10n t, AttendanceAction action, String userName) {
  return switch (action) {
    AttendanceAction.clockIn =>
      (title: t.pfSuccessClockedIn, greeting: t.pfSuccessClockedInMsg(userName)),
    AttendanceAction.clockOut =>
      (title: t.pfSuccessClockedOut, greeting: t.pfSuccessClockedOutMsg(userName)),
    AttendanceAction.breakShortPaid =>
      (title: t.pfSuccessOn10MinBreak, greeting: t.pfSuccessOn10MinBreakMsg(userName)),
    AttendanceAction.breakLongUnpaid =>
      (title: t.pfSuccessMealBreak, greeting: t.pfSuccessMealBreakMsg(userName)),
    AttendanceAction.breakEnd =>
      (title: t.pfSuccessBackToWork, greeting: t.pfSuccessBackToWorkMsg(userName)),
  };
}

class SuccessModal extends StatefulWidget {
  final String userName;
  final AttendanceAction action;
  final VoidCallback onClose;
  final bool autoClose;
  final Duration autoCloseAfter;

  const SuccessModal({
    super.key,
    required this.userName,
    required this.action,
    required this.onClose,
    this.autoClose = true,
    this.autoCloseAfter = const Duration(seconds: 5),
  });

  @override
  State<SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<SuccessModal> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoClose) {
      _timer = Timer(widget.autoCloseAfter, widget.onClose);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final msg = _localizedSuccess(t, widget.action, widget.userName);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.successBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 44, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  msg.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg.greeting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      t.pfSuccessOk,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (widget.autoClose) ...[
                  const SizedBox(height: 12),
                  Text(
                    t.pfSuccessAutoClose,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
