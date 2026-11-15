import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/network/auth_interceptor.dart';
import 'package:frontend/core/network/error_interceptor.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';

/// Counter incremented whenever token rotation fails and session is expired.
final StateProvider<int> sessionExpiredTriggerProvider = StateProvider<int>((ref) => 0);

/// Base options provider for Dio HTTP configuration.
final Provider<BaseOptions> dioBaseOptionsProvider = Provider<BaseOptions>((ref) {
  return BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    sendTimeout: ApiConstants.sendTimeout,
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
});

/// Dedicated Dio instance for token refresh operations to prevent interceptor recursion.
final Provider<Dio> refreshDioProvider = Provider<Dio>((ref) {
  final options = ref.watch(dioBaseOptionsProvider);
  return Dio(options);
});

/// Configured Dio instance with AuthInterceptor and ErrorInterceptor.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final options = ref.watch(dioBaseOptionsProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final refreshDio = ref.watch(refreshDioProvider);

  final dio = Dio(options);

  dio.interceptors.addAll([
    AuthInterceptor(
      storage: storage,
      dio: dio,
      refreshDio: refreshDio,
      onSessionExpired: () {
        ref.read(sessionExpiredTriggerProvider.notifier).state++;
      },
    ),
    ErrorInterceptor(),
  ]);

  return dio;
});

/// ApiClient provider for high-level HTTP operations across the application.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

/// Application API Client wrapping Dio with typed request/response handling.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapError(e);
    }
  }

  /// Verifies connectivity to Oversee Backend via GET /health.
  Future<Map<String, dynamic>> checkHealth() async {
    final response = await get<Map<String, dynamic>>(ApiConstants.health);
    return response.data ?? <String, dynamic>{};
  }

  Object _unwrapError(DioException e) {
    if (e.error is AppException) {
      return e.error as AppException;
    }
    return e;
  }
}
