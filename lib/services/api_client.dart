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

  bool isRefreshing = false;

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401 && !isRefreshing) {
        isRefreshing = true;
        try {
          final refreshToken = await TokenStorage.getRefreshToken();
          if (refreshToken == null) {
            await TokenStorage.clearTokens();
            isRefreshing = false;
            return handler.next(error);
          }

          // 별도 Dio 인스턴스로 리프레시 — Use separate Dio to avoid interceptor loop
          final refreshDio = Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            headers: {'Content-Type': 'application/json'},
          ));
          final response = await refreshDio.post('/app/auth/refresh', data: {
            'refresh_token': refreshToken,
          });

          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];
          await TokenStorage.setTokens(newAccessToken, newRefreshToken);

          // 원래 요청 재시도 — Retry original request with new token
          error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await dio.fetch(error.requestOptions);
          isRefreshing = false;
          return handler.resolve(retryResponse);
        } catch (_) {
          await TokenStorage.clearTokens();
          isRefreshing = false;
          return handler.next(error);
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});
