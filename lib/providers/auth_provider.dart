import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/token_storage.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

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

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

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

  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authService.register(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
      );
      final data = await _authService.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(data));
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: _parseError(e, 'Registration failed'));
      return false;
    }
  }

  /// Dio 에러 응답을 사용자 친화적 메시지로 변환
  String _parseError(Object e, String fallback) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        // 서버 에러: {"detail": "message"}
        if (detail is String) return detail;
        // 422 유효성 에러: {"detail": [{"loc": [...], "msg": "..."}]}
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

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
