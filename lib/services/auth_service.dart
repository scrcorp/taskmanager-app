import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/token_storage.dart';
import 'api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final companyCode = await TokenStorage.getCompanyCode();
    final response = await _dio.post('/app/auth/login', data: {
      'email': username,
      'password': password,
      if (companyCode != null) 'company_code': companyCode,
    });
    final data = response.data;
    await TokenStorage.setTokens(
      data['access_token'],
      data['refresh_token'],
    );
    return data['user'] ?? data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    final companyCode = await TokenStorage.getCompanyCode();
    final response = await _dio.post('/app/auth/register', data: {
      'email': email ?? username,
      'password': password,
      'name': fullName,
      'username': username,
      if (phone != null) 'phone': phone,
      if (companyCode != null) 'company_code': companyCode,
    });
    final data = response.data;
    await TokenStorage.setTokens(
      data['access_token'],
      data['refresh_token'],
    );
    return data['user'] ?? data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/app/auth/me');
    return response.data;
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
  }
}
