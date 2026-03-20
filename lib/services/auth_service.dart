/// 인증(Auth) API 서비스
///
/// 로그인, 회원가입, 내 정보 조회, 로그아웃 API 호출을 담당.
/// 앱 전용 인증 엔드포인트(/app/auth/*)를 사용하며,
/// 성공 시 JWT 토큰을 TokenStorage에 자동 저장.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
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
    final companyCode = await TokenStorage.getCompanyCode()
        ?? (AppConstants.defaultCompanyCode.isNotEmpty ? AppConstants.defaultCompanyCode : null);
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
  /// company_code는 TokenStorage에서 가져옴 (로그인과 동일).
  /// 성공 시 자동 로그인되어 토큰이 저장됨.
  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String verificationToken,
  }) async {
    final companyCode = await TokenStorage.getCompanyCode()
        ?? (AppConstants.defaultCompanyCode.isNotEmpty ? AppConstants.defaultCompanyCode : null);
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

  /// 아이디 찾기 — 이메일로 마스킹된 username 조회
  Future<Map<String, dynamic>> findUsername(String email) async {
    final response = await _dio.post('/auth/find-username', data: {'email': email});
    return response.data;
  }

  /// 아이디 찾기 — 인증코드 발송
  Future<Map<String, dynamic>> findUsernameSendCode(String email) async {
    final response = await _dio.post('/auth/find-username/send-code', data: {'email': email});
    return response.data;
  }

  /// 아이디 찾기 — 인증코드 검증 (full username 반환)
  Future<Map<String, dynamic>> findUsernameVerifyCode(String email, String code) async {
    final response = await _dio.post('/auth/find-username/verify-code', data: {
      'email': email,
      'code': code,
    });
    return response.data;
  }

  /// 비밀번호 재설정 — 인증코드 발송
  Future<Map<String, dynamic>> resetPasswordSendCode(String username, String email) async {
    final response = await _dio.post('/auth/reset-password/send-code', data: {
      'username': username,
      'email': email,
    });
    return response.data;
  }

  /// 비밀번호 재설정 — 인증코드 검증 (reset_token 반환)
  Future<Map<String, dynamic>> resetPasswordVerifyCode(String email, String code) async {
    final response = await _dio.post('/auth/reset-password/verify-code', data: {
      'email': email,
      'code': code,
    });
    return response.data;
  }

  /// 비밀번호 재설정 — 새 비밀번호 확정
  Future<Map<String, dynamic>> resetPasswordConfirm(String resetToken, String newPassword) async {
    final response = await _dio.post('/auth/reset-password/confirm', data: {
      'reset_token': resetToken,
      'new_password': newPassword,
    });
    return response.data;
  }

  /// 비밀번호 변경 (로그인 상태) — 새 토큰 쌍 반환
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final response = await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return response.data;
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
