/// ActionSheet — 본인 확인 후 액션 선택.
///
/// mockup 결정 (2026-05-22):
///   - 상단: "Choose Action" + 이름 + X close
///   - on_break + currentBreak → break info 박스 (상단)
///   - 5개 액션 grid 2-col: Clock In / Clock Out / 10min Break / Meal Break / End Break
///   - today_status 기반 활성/비활성
///   - on_break 일 때:
///     · End Break — breakProgress.canEndBreak 일 때만 활성 (10/30m 미달 disabled)
///     · Clock Out — 항상 활성 (긴급)

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/attendance_action.dart';
import '../models/identify_response.dart';
import '../utils/attendance_action_policy.dart';
import '../utils/staff_status_utils.dart';
import 'identity_confirm_dialog.dart' show localizedBreakLabel, localizedBreakHint;

/// AttendanceAction → 표시 라벨 + subtitle (l10n).
({String label, String sub}) localizedAction(AppL10n t, AttendanceAction a) => switch (a) {
      AttendanceAction.clockIn => (label: t.pfActionClockIn, sub: t.pfActionClockInSub),
      AttendanceAction.clockOut => (label: t.pfActionClockOut, sub: t.pfActionClockOutSub),
      AttendanceAction.breakShortPaid => (label: t.pfActionBreakShort, sub: t.pfActionBreakShortSub),
      AttendanceAction.breakLongUnpaid => (label: t.pfActionBreakLong, sub: t.pfActionBreakLongSub),
      AttendanceAction.breakEnd => (label: t.pfActionBreakEnd, sub: t.pfActionBreakEndSub),
    };

class ActionSheet extends StatelessWidget {
  final IdentifyResponse user;
  final ValueChanged<AttendanceAction> onPick;
  final VoidCallback onCancel;
  final DateTime? now;
  /// 매장의 워크인 허용 여부 — 스케줄 없을 때 Clock In 활성화 여부 결정.
  final bool walkInAllowed;

  const ActionSheet({
    super.key,
    required this.user,
    required this.onPick,
    required this.onCancel,
    this.now,
    this.walkInAllowed = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = now ?? DateTime.now();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(userName: user.userName, onCancel: onCancel),
                const SizedBox(height: 20),
                if (user.todayStatus == 'on_break' && user.currentBreak != null)
                  _BreakInfo(user: user, now: n),
                if (user.todayStatus == 'on_break' && user.currentBreak != null)
                  const SizedBox(height: 16),
                _ActionsGrid(user: user, onPick: onPick, now: n, walkInAllowed: walkInAllowed),
                const SizedBox(height: 16),
                Text(
                  AppL10n.of(context).pfActionHint,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final VoidCallback onCancel;
  const _Header({required this.userName, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppL10n.of(context).pfActionHeader,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close_rounded, size: 28, color: AppColors.textSecondary),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

class _BreakInfo extends StatelessWidget {
  final IdentifyResponse user;
  final DateTime now;
  const _BreakInfo({required this.user, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final br = user.currentBreak!;
    final elapsed = now.difference(br.startedAt).inMinutes;
    final progress = breakProgress(br.breakType, elapsed);
    final warn = progress.state != BreakState.within;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: warn ? AppColors.dangerBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedBreakLabel(t, br.breakType).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: warn ? AppColors.danger : AppColors.warning,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  localizedBreakHint(t, progress, br.breakType),
                  style: TextStyle(
                    fontSize: 11,
                    color: (warn ? AppColors.danger : AppColors.warning).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            t.pfBreakElapsed(progress.elapsedMinutes),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: warn ? AppColors.danger : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  final IdentifyResponse user;
  final ValueChanged<AttendanceAction> onPick;
  final DateTime now;
  final bool walkInAllowed;
  const _ActionsGrid({required this.user, required this.onPick, required this.now, this.walkInAllowed = false});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final actions = <({AttendanceAction action, IconData icon})>[
      (action: AttendanceAction.clockIn, icon: Icons.login_rounded),
      (action: AttendanceAction.clockOut, icon: Icons.logout_rounded),
      (action: AttendanceAction.breakShortPaid, icon: Icons.coffee_rounded),
      (action: AttendanceAction.breakLongUnpaid, icon: Icons.restaurant_rounded),
      (action: AttendanceAction.breakEnd, icon: Icons.play_arrow_rounded),
    ];

    final br = user.currentBreak;
    final elapsed = br == null ? 0 : now.difference(br.startedAt).inMinutes;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final e in actions)
          SizedBox(
            width: 320,
            child: _ActionTile(
              action: e.action,
              icon: e.icon,
              labels: localizedAction(t, e.action),
              allowed: isActionAllowed(
                todayStatus: user.todayStatus,
                action: e.action,
                currentBreakType: br?.breakType,
                currentBreakElapsedMinutes: elapsed,
                walkInAllowed: walkInAllowed,
              ),
              breakLockedHint: _hintFor(t, e.action, br?.breakType, elapsed),
              onTap: () => onPick(e.action),
            ),
          ),
      ],
    );
  }

  String? _hintFor(AppL10n t, AttendanceAction a, String? breakType, int elapsed) {
    final raw = breakLockedHint(
      todayStatus: user.todayStatus,
      action: a,
      currentBreakType: breakType,
      currentBreakElapsedMinutes: elapsed,
    );
    if (raw == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(raw);
    return m == null ? raw : t.pfActionWaitMore(int.parse(m.group(1)!));
  }
}

class _ActionTile extends StatelessWidget {
  final AttendanceAction action;
  final IconData icon;
  final ({String label, String sub}) labels;
  final bool allowed;
  final String? breakLockedHint;
  final VoidCallback onTap;
  const _ActionTile({
    required this.action,
    required this.icon,
    required this.labels,
    required this.allowed,
    required this.breakLockedHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileBg = allowed ? AppColors.white : AppColors.bg.withValues(alpha: 0.4);
    final iconBg = allowed ? AppColors.accentBg : AppColors.bg;
    final iconFg = allowed ? AppColors.accent : AppColors.textMuted;
    final labelColor = allowed ? AppColors.text : AppColors.textMuted;

    return InkWell(
      onTap: allowed ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: allowed ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: iconFg),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    breakLockedHint ?? labels.sub,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
