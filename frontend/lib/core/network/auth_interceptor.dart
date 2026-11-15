import 'package:dio/dio.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';

/// Interceptor that attaches JWT Bearer token to requests and coordinates
/// automatic Refresh Token Rotation upon encountering HTTP 401 Unauthorized.
class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  final Dio _refreshDio;
  final void Function()? _onSessionExpired;

  AuthInterceptor({
    required SecureStorageService storage,
    required Dio dio,
    required Dio refreshDio,
    void Function()? onSessionExpired,
  })  : _storage = storage,
        _dio = dio,
        _refreshDio = refreshDio,
        _onSessionExpired = onSessionExpired;

  static const List<String> _publicEndpoints = [
    ApiConstants.login,
    ApiConstants.register,
    ApiConstants.refresh,
    ApiConstants.health,
  ];

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isPublic = _publicEndpoints.any((endpoint) => options.path.contains(endpoint));

    if (!isPublic && options.extra['is_retry'] != true) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Only process 401 Unauthorized errors
    if (statusCode == 401) {
      // If already retried once or if path is refresh/login, do not loop
      if (err.requestOptions.extra['is_retry'] == true ||
          path.contains(ApiConstants.refresh) ||
          path.contains(ApiConstants.login)) {
        await _handleSessionExpired();
        return handler.next(err);
      }

      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _handleSessionExpired();
        return handler.next(err);
      }

      try {
        // Attempt to rotate refresh token via POST /auth/refresh
        final refreshResponse = await _refreshDio.post<Map<String, dynamic>>(
          ApiConstants.refresh,
          data: {'refresh_token': refreshToken},
        );

        if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
          final data = refreshResponse.data!;
          final newAccessToken = data['access_token'] as String;
          final newRefreshToken = data['refresh_token'] as String;

          // Save newly rotated tokens
          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // Retry original request with newly issued access token
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          requestOptions.extra['is_retry'] = true;

          final response = await _dio.fetch<dynamic>(requestOptions);
          return handler.resolve(response);
        } else {
          await _handleSessionExpired();
          return handler.next(err);
        }
      } catch (_) {
        // Refresh failed (token revoked or expired)
        await _handleSessionExpired();
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  Future<void> _handleSessionExpired() async {
    await _storage.clearAll();
    _onSessionExpired?.call();
  }
}
