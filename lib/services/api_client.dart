/// HTTP 클라이언트(Dio) 설정 및 인증 인터셉터
///
/// 모든 API 호출에 사용되는 Dio 인스턴스를 생성하고,
/// JWT 토큰 자동 주입 + 401 응답 시 토큰 갱신(refresh) 로직을 처리.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../utils/token_storage.dart';

/// Dio 싱글턴 Provider
///
/// 앱 전역에서 하나의 Dio 인스턴스를 공유.
/// baseUrl, 타임아웃, Content-Type 기본 헤더를 설정하고
/// AuthInterceptor를 등록하여 모든 요청에 인증 헤더를 자동 추가.
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

/// JWT 인증 인터셉터
///
/// 요청 전: 저장된 access token을 Authorization 헤더에 주입.
/// 에러 시: 401 응답이면 refresh token으로 새 토큰 발급 후 원래 요청을 재시도.
/// 갱신 실패 시 토큰을 삭제하여 로그아웃 상태로 전환.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  /// 동시 다발적 401 요청 시 중복 갱신 방지 플래그
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  /// 모든 요청에 access token을 Bearer 헤더로 주입
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// 401 Unauthorized 응답 시 토큰 갱신 및 요청 재시도
  ///
  /// 1) refresh token으로 /auth/refresh 호출하여 새 토큰 쌍 발급
  /// 2) 새 access token으로 원래 요청을 재시도 (resolve)
  /// 3) 갱신 실패 시 모든 토큰 삭제 (로그아웃 처리)
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken != null) {
          // 별도 Dio 인스턴스로 갱신 요청 (인터셉터 순환 방지)
          final response = await Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
          )).post('/auth/refresh', data: {'refresh_token': refreshToken});

          final newAccess = response.data['access_token'] as String;
          // 서버가 새 refresh token을 반환하지 않으면 기존 것 유지
          final newRefresh = response.data['refresh_token'] as String? ?? refreshToken;
          await TokenStorage.setTokens(newAccess, newRefresh);

          // 새 토큰으로 원래 요청 재시도
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await _dio.fetch(err.requestOptions);
          _isRefreshing = false;
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // 갱신 실패 시 토큰 삭제 → 로그아웃 상태로 전환
        await TokenStorage.clearTokens();
      }
      _isRefreshing = false;
    }
    handler.next(err);
  }
}
