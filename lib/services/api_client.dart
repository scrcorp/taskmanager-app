import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../utils/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(dio));
  return dio;
});

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken != null) {
          final response = await Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
          )).post('/app/auth/refresh', data: {'refresh_token': refreshToken});

          final newAccess = response.data['access_token'] as String;
          final newRefresh = response.data['refresh_token'] as String? ?? refreshToken;
          await TokenStorage.setTokens(newAccess, newRefresh);

          // Retry the original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await _dio.fetch(err.requestOptions);
          _isRefreshing = false;
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        await TokenStorage.clearTokens();
      }
      _isRefreshing = false;
    }
    handler.next(err);
  }
}
