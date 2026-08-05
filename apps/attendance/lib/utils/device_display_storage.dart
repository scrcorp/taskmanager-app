/// 화면 표시 관련 기기 설정 로컬 저장소.
///
/// 매장 태블릿마다 설치 위치(창가/조명 아래)가 달라 밝기는 기기별 설정이다.
/// 서버에 올리지 않고 기기에만 남긴다.
import 'package:shared_preferences/shared_preferences.dart';

class DeviceDisplayStorage {
  static const _brightnessKey = 'attendance_screen_brightness';

  /// 저장된 밝기(0.0~1.0). 설정한 적 없으면 null = 시스템 밝기를 따름.
  static Future<double?> getBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_brightnessKey);
  }

  static Future<void> setBrightness(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_brightnessKey, value);
  }

  /// 시스템 밝기로 되돌리기 — 저장값 삭제.
  static Future<void> clearBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_brightnessKey);
  }
}
