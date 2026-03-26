/// 인증(Auth) 상태 관리 Provider
///
/// JWT 토큰 기반 인증 흐름을 관리한다:
/// 1. checkAuth(): 저장된 토큰으로 자동 로그인 시도
/// 2. login(): 사용자명+비밀번호로 로그인
/// 3. register(): 회사코드 기반 회원가입
/// 4. logout(): 토큰 삭제 및 로그아웃
///
/// Dio 에러를 사용자 친화적 메시지로 변환하는 _parseError() 포함.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/token_storage.dart';

/// 인증 상태 열거형
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// 인증 상태 데이터 클래스
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// 인증 상태 Provider (앱 전역에서 접근)
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

/// 인증 상태 관리 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  /// 앱 시작 시 저장된 토큰으로 인증 상태 확인
  ///
  /// 토큰이 없으면 즉시 unauthenticated,
  /// 토큰이 있으면 /auth/me로 유효성 검증 후 사용자 정보 로드.
  Future<void> checkAuth() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final data = await _authService.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(data));
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 사용자명+비밀번호로 로그인
  ///
  /// 성공 시 true 반환 + authenticated 상태 전환.
  /// 실패 시 false 반환 + 에러 메시지 설정.
  Future<bool> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authService.login(username, password);
      final data = await _authService.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(data));
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: _parseError(e, 'Login failed'));
      return false;
    }
  }

  /// 회원가입 (회사코드 기반)
  ///
  /// TokenStorage에 저장된 회사코드를 사용하여 조직에 가입.
  /// 성공 시 자동으로 인증 상태로 전환.
  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String verificationToken,
    List<String> storeIds = const [],
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authService.register(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
        verificationToken: verificationToken,
        storeIds: storeIds,
      );
      final data = await _authService.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(data));
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: _parseError(e, 'Registration failed'));
      return false;
    }
  }

  /// 로그인 후 이메일 인증 완료 — getMe()로 사용자 정보 갱신
  Future<void> refreshUser() async {
    try {
      final data = await _authService.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(data));
    } catch (_) {}
  }

  /// 비밀번호 변경 — 새 토큰으로 현재 세션 유지
  ///
  /// 성공 시 서버가 반환한 새 토큰을 저장하고 사용자 정보를 갱신.
  /// 다른 기기의 세션은 서버에서 자동으로 무효화됨.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final data = await _authService.changePassword(currentPassword, newPassword);
      await TokenStorage.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      await refreshUser();
      return true;
    } catch (e) {
      state = state.copyWith(error: _parseError(e, 'Failed to change password'));
      return false;
    }
  }

  /// Dio 에러 응답을 사용자 친화적 메시지로 변환
  ///
  /// - 서버 에러: {"detail": "message"} → 메시지 직접 표시
  /// - 422 유효성 에러: {"detail": [{"loc": [...], "msg": "..."}]} → 필드별 에러
  /// - 네트워크 에러: 타임아웃/연결 불가 시 안내 메시지
  String _parseError(Object e, String fallback) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((d) {
            final loc = (d['loc'] as List?)?.where((l) => l != 'body').join(' > ') ?? '';
            final msg = d['msg'] ?? '';
            return loc.isNotEmpty ? '$loc: $msg' : msg;
          }).join('\n');
        }
      }
    }
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server not responding. Please try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'No internet connection.';
      }
    }
    return fallback;
  }

  /// 로그아웃: 서버에 refresh token 무효화 요청 후 로컬 토큰 삭제
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
