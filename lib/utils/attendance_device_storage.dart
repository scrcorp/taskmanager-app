/// 태블릿 기기(device) 토큰 로컬 저장소
///
/// 매장 공용 태블릿용 attendance 기기 인증 정보를 SharedPreferences에 저장한다.
/// 일반 사용자 JWT(TokenStorage)와는 완전히 분리된 auth scope.
///
/// 저장 항목:
/// - device token: `/api/v1/attendance/register` 성공 시 발급 (무기한)
/// - device fingerprint: register 요청 시 재사용하기 위한 브라우저/기기 식별자
import 'package:shared_preferences/shared_preferences.dart';

/// 기기 토큰 저장소 — 정적 메서드만 제공
class AttendanceDeviceStorage {
  static const _tokenKey = 'attendance_device_token';
  static const _fingerprintKey = 'attendance_device_fingerprint';

  /// 기기 토큰 저장
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 기기 토큰 조회 (없으면 null)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 기기 토큰 삭제 (unregister / 401 에러 시)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// 브라우저/기기 fingerprint 조회 — 없으면 null
  static Future<String?> getFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fingerprintKey);
  }

  /// fingerprint 저장 — 첫 register 후 유지하여 이후에도 동일한 값 사용
  static Future<void> setFingerprint(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fingerprintKey, fingerprint);
  }
}
