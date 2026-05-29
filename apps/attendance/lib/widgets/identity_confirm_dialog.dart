/// IdentityConfirmDialog — PIN 식별 후 본인 확인.
///
/// mockup 결정 (2026-05-22):
///   - 큰 이니셜 아바타 + "IS THIS YOU?" + 이름
///   - status 분기:
///     · today_status null (no shift) → orange box "NO SHIFT TODAY" + Close 만
///     · clocked_out → gray box "Shift completed" + Close 만
///     · on_break + current_break → break info 박스 (label + Nm elapsed + hint)
///     · 그 외 (working/upcoming/late/soon/no_show) → status badge + Yes/Close
///
/// Phase 5 Main 화면에서 PIN 식별 후 노출.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/identify_response.dart';
import '../utils/identity_confirm_logic.dart';
import '../utils/staff_status_utils.dart';

/// status → 표시 라벨 (l10n).
String _localizedStatusLabel(AppL10n t, String status) => switch (status) {
      'working' => t.pfStatusWorking,
      'on_break' => t.pfStatusOnBreak,
      'upcoming' => t.pfStatusUpcoming,
      'soon' => t.pfStatusSoon,
      'late' => t.pfStatusLate,
      'no_show' => t.pfStatusNoShow,
      'clocked_out' => t.pfStatusClockedOut,
      _ => labelForStatus(status),
    };

/// break_type → 표시 라벨 (l10n).
String localizedBreakLabel(AppL10n t, String breakType) {
  if (breakType == 'unpaid_meal' || breakType == 'unpaid_long') return t.pfBreakLabelMealUnpaid;
  if (breakType == 'paid_10min' || breakType == 'paid_short') return t.pfBreakLabelPaid10Min;
  return t.pfBreakLabelOnBreak;
}

/// breakProgress hint → l10n.
String localizedBreakHint(AppL10n t, BreakProgress p, String breakType) {
  final isPaid = breakType == 'paid_10min' || breakType == 'paid_short';
  switch (p.state) {
    case BreakState.tooShort:
      return isPaid
          ? t.pfBreakHintPaidTooShort(p.remainingMinutes)
          : t.pfBreakHintMealTooShort(p.remainingMinutes);
    case BreakState.within:
      return isPaid ? t.pfBreakHintPaidWithin : t.pfBreakHintMealWithin;
    case BreakState.overAllowance:
      return t.pfBreakHintPaidOver(p.elapsedMinutes - 10);
    case BreakState.requiresReason:
      return t.pfBreakHintMealRequiresReason;
  }
}

class IdentityConfirmDialog extends StatelessWidget {
  final IdentifyResponse user;
  final VoidCallback onYes;
  final VoidCallback onClose;
  final DateTime? now;

  const IdentityConfirmDialog({
    super.key,
    required this.user,
    required this.onYes,
    required this.onClose,
    this.now,
  });

  bool get _closeOnly => isCloseOnly(user.todayStatus);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final initials = initialsOf(user.userName);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.pfIdHeader,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.userName,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _StatusPanel(user: user, now: now ?? DateTime.now()),
                if (user.staleAttendances.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _StaleWarning(items: user.staleAttendances),
                ],
                const SizedBox(height: 28),
                _buildButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final t = AppL10n.of(context);
    if (_closeOnly) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(t.pfIdClose, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(t.pfIdClose, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: onYes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                t.pfIdYes,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 이전 work_date 미완료 경고 배너 (Issue 11). 최신 3개 날짜 + "+N more".
class _StaleWarning extends StatelessWidget {
  final List<StaleAttendanceItem> items;
  const _StaleWarning({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    const maxShown = 3;
    final shown = items.take(maxShown).map((e) => e.workDate).join(', ');
    final moreCount = items.length - maxShown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.pfStaleWarnTitle(items.length),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.pfStaleWarnBody,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            moreCount > 0 ? '$shown  ${t.pfStaleMore(moreCount)}' : shown,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IdentifyResponse user;
  final DateTime now;
  const _StatusPanel({required this.user, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final status = user.todayStatus;

    // No shift
    if (status == null) {
      return _Panel(
        bg: AppColors.warningBg,
        fg: AppColors.warning,
        title: t.pfIdNoShiftTitle,
        body: t.pfIdNoShiftBody,
      );
    }

    // On break + current_break → break info
    if (status == 'on_break' && user.currentBreak != null) {
      final br = user.currentBreak!;
      final elapsed = now.difference(br.startedAt).inMinutes;
      final progress = breakProgress(br.breakType, elapsed);
      final warn = progress.state != BreakState.within;
      return _Panel(
        bg: warn ? AppColors.dangerBg : AppColors.warningBg,
        fg: warn ? AppColors.danger : AppColors.warning,
        title: t.pfBreakOnBreakTitle(localizedBreakLabel(t, br.breakType).toUpperCase()),
        big: t.pfBreakElapsed(progress.elapsedMinutes),
        body: localizedBreakHint(t, progress, br.breakType),
      );
    }

    // 기타 상태 — 라벨 + 색
    final (bg, fg) = _colorsFor(status);
    return _Panel(bg: bg, fg: fg, title: _localizedStatusLabel(t, status));
  }

  (Color, Color) _colorsFor(String status) {
    switch (status) {
      case 'working':
        return (AppColors.successBg, AppColors.success);
      case 'on_break':
      case 'late':
        return (AppColors.warningBg, AppColors.warning);
      case 'upcoming':
      case 'soon':
        return (AppColors.accentBg, AppColors.accent);
      case 'no_show':
        return (AppColors.dangerBg, AppColors.danger);
      case 'clocked_out':
      default:
        return (AppColors.bg, AppColors.textSecondary);
    }
  }
}

class _Panel extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String title;
  final String? big;
  final String? body;
  const _Panel({required this.bg, required this.fg, required this.title, this.big, this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (big != null) ...[
            const SizedBox(height: 4),
            Text(
              big!,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
            ),
          ],
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body!,
              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

