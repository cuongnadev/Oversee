import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/domain/token_model.dart';
import 'package:frontend/features/auth/domain/user_model.dart';

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// Authenticates user and returns tokens.
  Future<TokenModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return TokenModel.fromJson(response.data!);
  }

  /// Registers a new user account.
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': fullName.trim(),
      },
    );
    return UserModel.fromJson(response.data!);
  }

  /// Fetches the authenticated user profile (`GET /users/me`).
  Future<UserModel> getCurrentUser() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.currentUser,
    );
    return UserModel.fromJson(response.data!);
  }

  /// Revokes refresh token on backend.
  Future<void> logout({required String refreshToken}) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.logout,
      data: {
        'refresh_token': refreshToken,
      },
    );
  }
}
