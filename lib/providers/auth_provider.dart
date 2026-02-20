import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

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
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
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
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
