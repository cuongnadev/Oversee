import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthNotifier(storage);
});

/// Listenable adapter so GoRouter can react to authentication state changes.
final routerListenableProvider = Provider<ValueNotifier<AuthStatus>>((ref) {
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

  AuthNotifier(this._storage, {AuthState? initialState})
      : super(initialState ?? const AuthState(status: AuthStatus.unauthenticated)) {
    if (initialState == null) {
      checkAuthStatus();
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        state = state.copyWith(status: AuthStatus.authenticated, accessToken: token);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> setAuthenticated({required String accessToken, required String refreshToken, String? email}) async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      accessToken: accessToken,
      email: email,
    );
    try {
      await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
    try {
      await _storage.clearAll();
    } catch (_) {}
  }
}
