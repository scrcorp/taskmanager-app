/// JWT 토큰 및 회사 코드 로컬 저장소
///
/// SharedPreferences를 래핑하여 access/refresh 토큰과 company_code를 관리.
/// 앱 인증 흐름에서 사용:
/// - 로그인/회원가입 성공 → setTokens()
/// - API 요청 시 → getAccessToken()
/// - 토큰 갱신 시 → getRefreshToken() + setTokens()
/// - 로그아웃 시 → clearTokens()
/// - 회사 코드 입력 시 → setCompanyCode()
import 'package:shared_preferences/shared_preferences.dart';

/// 토큰 저장소 — 정적 메서드만 제공 (인스턴스 불필요)
class TokenStorage {
  static const _accessTokenKey = 'taskmanager_access_token';
  static const _refreshTokenKey = 'taskmanager_refresh_token';
  static const _companyCodeKey = 'taskmanager_company_code';

  /// access + refresh 토큰 쌍을 저장
  static Future<void> setTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  /// 저장된 access token 반환 (없으면 null)
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// 저장된 refresh token 반환 (없으면 null)
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// 모든 토큰 삭제 (로그아웃 처리)
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  /// 저장된 회사 코드 반환
  static Future<String?> getCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyCodeKey);
  }

  /// 회사 코드 저장 (대문자 변환하여 저장)
  static Future<void> setCompanyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyCodeKey, code.toUpperCase());
  }

  /// 회사 코드가 저장되어 있는지 확인
  static Future<bool> hasCompanyCode() async {
    final code = await getCompanyCode();
    return code != null && code.isNotEmpty;
  }
}
