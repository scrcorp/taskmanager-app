import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../utils/token_storage.dart';
import 'mock_services.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConstants.useMock) return MockAuthService();
  return AuthService(ref.read(dioProvider));
});

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Future<void> login(String username, String password) async {
    final companyCode = await TokenStorage.getCompanyCode();
    final response = await _dio.post('/app/auth/login', data: {
      'username': username,
      'password': password,
      if (companyCode != null) 'company_code': companyCode,
    });
    await TokenStorage.setTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    final companyCode = await TokenStorage.getCompanyCode();
    final response = await _dio.post('/app/auth/register', data: {
      'username': username,
      'password': password,
      'full_name': fullName,
      if (email != null) 'email': email,
      'company_code': companyCode ?? '',
    });
    await TokenStorage.setTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/app/auth/me');
    return response.data;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post('/app/auth/logout', data: {
          'refresh_token': refreshToken,
        });
      }
    } catch (_) {
      // 서버 로그아웃 실패해도 로컬 토큰은 삭제 — Clear local tokens even if server call fails
    }
    await TokenStorage.clearTokens();
  }
}
