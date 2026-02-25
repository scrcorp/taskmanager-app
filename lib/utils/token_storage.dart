import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _accessTokenKey = 'taskmanager_access_token';
  static const _refreshTokenKey = 'taskmanager_refresh_token';
  static const _companyCodeKey = 'taskmanager_company_code';

  static Future<void> setTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<String?> getCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyCodeKey);
  }

  static Future<void> setCompanyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyCodeKey, code.toUpperCase());
  }

  static Future<bool> hasCompanyCode() async {
    final code = await getCompanyCode();
    return code != null && code.isNotEmpty;
  }
}
