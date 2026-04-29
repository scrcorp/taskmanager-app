/// 키오스크 잠금을 의도적으로 유지할지 여부.
///
/// true  : 부팅/resume 시 자동으로 Lock Task 모드 시작
/// false : 관리자가 명시적으로 Exit Kiosk Mode 한 상태
///
/// 추가로 "임시 해제 + 자동 재잠금" 메커니즘 보유:
/// - `disableTemporarily()` 로 OFF 하면 5분 후(또는 지정 시간 후) 자동 ON.
/// - 영속(`_relockKey` 에 시각 저장) + in-memory Timer 둘 다 사용 →
///   앱 재시작 / 백그라운드 / 포그라운드 어떤 상태에서도 정확히 동작.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kiosk_lock.dart';

class KioskIntent {
  static const _key = 'kiosk_intent_enabled';
  static const _relockKey = 'kiosk_relock_at_ms';
  static const defaultTempDuration = Duration(minutes: 5);

  static Timer? _autoRelockTimer;

  /// 키오스크 ON/OFF 상태 변화 통지용. UI(예: Settings 토글) 가
  /// 이 notifier 를 listen 해 escape 게스처/타이머에 의한 변화도 즉시 반영.
  static final ValueNotifier<bool> stateNotifier = ValueNotifier<bool>(true);

  /// 키오스크가 ON 이어야 하는지 반환.
  ///
  /// `_relockKey` 시각이 지났으면 자동으로 enabled=true 로 승격하면서 true 반환.
  /// 따라서 호출 측은 별도 시간 비교 없이 isEnabled 만 신뢰하면 됨.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final relockAt = prefs.getInt(_relockKey);
    if (relockAt != null &&
        DateTime.now().millisecondsSinceEpoch >= relockAt) {
      await prefs.setBool(_key, true);
      await prefs.remove(_relockKey);
      stateNotifier.value = true;
      return true;
    }
    final value = prefs.getBool(_key) ?? true;
    stateNotifier.value = value;
    return value;
  }

  /// 명시적 ON/OFF (자동 재잠금 예약 제거)
  static Future<void> setEnabled(bool value) async {
    cancelAutoRelock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    await prefs.remove(_relockKey);
    stateNotifier.value = value;
  }

  /// 일시 해제 — [duration] 후 자동으로 다시 ON 됨.
  static Future<void> disableTemporarily({
    Duration duration = defaultTempDuration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    final relockAt =
        DateTime.now().add(duration).millisecondsSinceEpoch;
    await prefs.setInt(_relockKey, relockAt);
    stateNotifier.value = false;
    _scheduleTimer(duration);
  }

  /// 콜드 스타트/resume 시 호출 — 영속된 `_relockKey` 가 있으면 in-memory Timer 재무장.
  /// 이미 시각이 지났다면 즉시 재잠금.
  static Future<void> armTimerIfPending() async {
    final prefs = await SharedPreferences.getInstance();
    final relockAt = prefs.getInt(_relockKey);
    if (relockAt == null) return;
    final remainingMs =
        relockAt - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await _autoRelock();
      return;
    }
    _scheduleTimer(Duration(milliseconds: remainingMs));
  }

  /// 자동 재잠금 예약 취소 (수동으로 다시 ON 토글했을 때)
  static void cancelAutoRelock() {
    _autoRelockTimer?.cancel();
    _autoRelockTimer = null;
  }

  /// 임시해제 만료 시각(epoch ms). 표시용.
  static Future<DateTime?> relockAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_relockKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static void _scheduleTimer(Duration d) {
    _autoRelockTimer?.cancel();
    _autoRelockTimer = Timer(d, _autoRelock);
  }

  static Future<void> _autoRelock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    await prefs.remove(_relockKey);
    _autoRelockTimer = null;
    stateNotifier.value = true;
    if (!await KioskLock.isLocked()) {
      await KioskLock.start();
    }
  }
}
