/// Manage 모드 재설계(Issue 10) — state/anomaly/soon 색 토큰 (AppColors 기반).
///
/// 라벨/분류는 manage_status_utils, 색은 여기로 분리 (util 은 UI 의존 없게 유지).

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

({Color bg, Color fg}) manageStateColors(String state) {
  switch (state) {
    case 'working':
      return (bg: AppColors.successBg, fg: AppColors.success);
    case 'breaking':
      return (bg: AppColors.warningBg, fg: AppColors.warning);
    case 'done':
      return (bg: AppColors.bg, fg: AppColors.textMuted);
    case 'upcoming':
    default:
      return (bg: AppColors.accentBg, fg: AppColors.accent);
  }
}

({Color bg, Color fg}) manageAnomalyColors(String anomaly) {
  switch (anomaly) {
    case 'no_show':
    case 'overtime': // 중요 — 빨강 강조
      return (bg: AppColors.dangerBg, fg: AppColors.danger);
    case 'late':
    case 'early_leave':
    case 'no_break':
    default:
      return (bg: AppColors.warningBg, fg: AppColors.warning);
  }
}

/// soon — anomaly 아님(앱 자체 판단). late(amber)와 구분되게 accent.
({Color bg, Color fg}) get manageSoonColors => (bg: AppColors.accentBg, fg: AppColors.accent);
