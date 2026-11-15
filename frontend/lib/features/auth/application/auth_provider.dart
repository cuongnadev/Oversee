import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/user_model.dart';

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final repository = ref.watch(authRepositoryProvider);

  // Listen to session expired trigger from Dio AuthInterceptor
  ref.listen<int>(sessionExpiredTriggerProvider, (prev, next) {
    if (next > 0) {
      ref.read(authNotifierProvider.notifier).logout();
    }
  });

  return AuthNotifier(storage, repository: repository);
});

/// Listenable adapter so GoRouter can react to authentication state changes.
final Provider<ValueNotifier<AuthStatus>> routerListenableProvider =
    Provider<ValueNotifier<AuthStatus>>((ref) {
  final notifier = ValueNotifier<AuthStatus>(ref.read(authNotifierProvider).status);
  ref.listen<AuthState>(authNotifierProvider, (previous, next) {
    if (previous?.status != next.status) {
      notifier.value = next.status;
    }
  });
  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _storage;
  final AuthRepository? _repository;

  AuthNotifier(
    this._storage, {
    AuthRepository? repository,
    AuthState? initialState,
  })  : _repository = repository,
        super(initialState ?? const AuthState(status: AuthStatus.initial)) {
    if (initialState == null) {
      checkAuthStatus();
    }
  }

  /// Checks if stored token exists on app launch and restores user profile.
  /// Checks if stored token exists on app launch and restores user profile.
  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        state = state.copyWith(status: AuthStatus.authenticating, accessToken: token);
        final repo = _repository;
        if (repo != null) {
          try {
            final user = await repo.getCurrentUser();
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: user,
              email: user.email,
            );
          } catch (_) {
            // Token is invalid, expired, or user is inactive -> clear session
            await logout();
          }
        } else {
          state = state.copyWith(status: AuthStatus.authenticated, accessToken: token);
        }
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Performs user login with credentials.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    final repo = _repository;
    if (repo == null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        accessToken: 'mock_token',
        email: email,
      );
      return true;
    }

    try {
      final token = await repo.login(email: email, password: password);
      await _storage.saveTokens(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
      );

      // Fetch user profile
      UserModel? user;
      try {
        user = await repo.getCurrentUser();
      } catch (_) {
        user = UserModel(id: 'me', email: email, fullName: email.split('@').first);
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        accessToken: token.accessToken,
        email: user.email,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred during login. Please try again.',
      );
      return false;
    }
  }

  /// Registers a new user account via POST /api/v1/auth/register.
  /// Returns true on success, or false if registration fails.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    final repo = _repository;
    if (repo == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return true;
    }

    try {
      await repo.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred during registration. Please try again.',
      );
      return false;
    }
  }

  /// Sets authenticated state manually (used for tests or mock sessions).
  Future<void> setAuthenticated({
    required String accessToken,
    required String refreshToken,
    String? email,
    UserModel? user,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      accessToken: accessToken,
      email: email ?? user?.email,
      user: user,
      clearError: true,
    );
    try {
      await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    } catch (_) {}
  }

  /// Clears active error message.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Logs out user, revokes refresh token if possible, and clears local secure storage.
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      final repo = _repository;
      if (refreshToken != null && refreshToken.isNotEmpty && repo != null) {
        try {
          await repo.logout(refreshToken: refreshToken);
        } catch (_) {}
      }
    } catch (_) {}

    state = const AuthState(status: AuthStatus.unauthenticated);
    try {
      await _storage.clearAll();
    } catch (_) {}
  }
}
