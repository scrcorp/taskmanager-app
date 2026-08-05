/// 태블릿 하드웨어(배터리 / 화면 밝기) 네이티브 브리지.
///
/// 앱 고정(lock task) + immersiveSticky 조합이라 시스템 상태바와 빠른설정이
/// 완전히 가려진다. 그래서 배터리 확인도, 밝기 조절도 앱 안에서 해줘야 한다.
///
/// 네이티브 구현: android/app/src/main/kotlin/com/tigersplus/attendance/MainActivity.kt
/// 안드로이드 전용이며, 지원하지 않는 플랫폼(웹/테스트 환경)에서는
/// MissingPluginException 을 삼키고 안전한 기본값을 돌려준다.
import 'package:flutter/services.dart';

import '../models/battery_status.dart';

class DevicePower {
  static const _method = MethodChannel('com.tigersplus.app/device');
  static const _batteryEvents = EventChannel('com.tigersplus.app/battery');

  /// 슬라이더 최소값. 이보다 어두우면 화면이 사실상 안 보여서 키오스크를
  /// 되살릴 수 없다 (네이티브에도 동일 취지의 하한이 있음).
  static const minBrightness = 0.1;
  static const maxBrightness = 1.0;

  /// 배터리 상태 스트림. 구독하는 동안에만 네이티브 receiver 가 살아있고,
  /// 구독 즉시 현재 상태(sticky broadcast)가 한 번 흘러온다.
  static Stream<BatteryStatus> batteryStream() {
    return _batteryEvents.receiveBroadcastStream().map((event) {
      if (event is Map) return BatteryStatus.fromMap(event);
      return BatteryStatus.unknown;
    }).handleError((Object _) {
      // 안드로이드가 아니거나 채널이 없으면 조용히 unknown 으로 — 헤더의
      // 배터리 칩만 비면 되고 화면 전체가 에러로 죽으면 안 된다.
    });
  }

  /// 창 밝기 override 설정. [value] 는 0.0~1.0.
  static Future<bool> setBrightness(double value) async {
    final clamped = value.clamp(minBrightness, maxBrightness);
    try {
      return await _method.invokeMethod<bool>(
            'setBrightness',
            {'value': clamped},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 창 밝기 override 해제 → 시스템 밝기를 따라간다.
  static Future<bool> clearBrightness() async {
    try {
      return await _method.invokeMethod<bool>('clearBrightness') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 현재 창 밝기. override 가 없으면(시스템 밝기 사용 중) null.
  static Future<double?> getBrightness() async {
    try {
      final value = await _method.invokeMethod<double>('getBrightness');
      if (value == null || value < 0) return null;
      return value;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
