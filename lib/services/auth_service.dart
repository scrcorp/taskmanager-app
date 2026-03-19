/// 인증(Auth) API 서비스
///
/// 로그인, 회원가입, 내 정보 조회, 로그아웃 API 호출을 담당.
/// 앱 전용 인증 엔드포인트(/app/auth/*)를 사용하며,
/// 성공 시 JWT 토큰을 TokenStorage에 자동 저장.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/token_storage.dart';
import 'api_client.dart';

/// 인증 서비스 Provider (Dio 인스턴스 주입)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

/// 인증 API 서비스 클래스
class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  /// 로그인 — username/password + company_code로 인증
  ///
  /// 성공 시 access/refresh 토큰을 로컬에 저장.
  /// company_code는 TokenStorage에서 이전에 저장한 값을 자동으로 포함.
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

  /// 회원가입 — 직원이 company_code를 통해 조직에 가입
  ///
  /// company_code가 없으면 기본값 '3Y1FII' 사용 (개발용 하드코딩).
  /// 성공 시 자동 로그인되어 토큰이 저장됨.
  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String verificationToken,
  }) async {
    final companyCode = await TokenStorage.getCompanyCode() ?? '3Y1FII';
    final response = await _dio.post('/app/auth/register', data: {
      'username': username,
      'password': password,
      'full_name': fullName,
      'email': email,
      'company_code': companyCode,
      'verification_token': verificationToken,
    });
    await TokenStorage.setTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );
  }

  /// 이메일 인증코드 발송
  Future<Map<String, dynamic>> sendVerificationCode(
    String email, {
    String purpose = 'registration',
  }) async {
    final response = await _dio.post('/app/auth/send-verification-code', data: {
      'email': email,
      'purpose': purpose,
    });
    return response.data;
  }

  /// 이메일 인증코드 검증 — 성공 시 verification_token 반환
  Future<Map<String, dynamic>> verifyEmailCode(
    String email,
    String code,
  ) async {
    final response = await _dio.post('/app/auth/verify-email-code', data: {
      'email': email,
      'code': code,
    });
    return response.data;
  }

  /// 로그인 후 이메일 인증 (기존 사용자용)
  Future<void> confirmEmail(String email, String code) async {
    await _dio.post('/app/auth/confirm-email', data: {
      'email': email,
      'code': code,
    });
  }

  /// 내 정보 조회 — JWT 토큰으로 현재 사용자 프로필 반환
  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  /// 로그아웃 — 서버에 refresh_token 무효화 요청 후 로컬 토큰 삭제
  ///
  /// 서버 호출 실패해도 로컬 토큰은 반드시 삭제 (try-catch로 무시).
  Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {
          'refresh_token': refreshToken,
        });
      } catch (_) {}
    }
    await TokenStorage.clearTokens();
  }
}
