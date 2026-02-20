import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _accessKey = 'taskmanager_access_token';
  static const _refreshKey = 'taskmanager_refresh_token';
  static const _companyCodeKey = 'taskmanager_company_code';

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> setTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null;
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
