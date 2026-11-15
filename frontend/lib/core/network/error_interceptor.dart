import 'package:dio/dio.dart';
import 'package:frontend/core/errors/app_exception.dart';

/// Interceptor that translates Dio HTTP errors and Oversee backend ErrorResponse
/// into typed Dart AppException instances.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = _mapDioExceptionToAppException(err);
    final enrichedError = err.copyWith(error: appException);
    handler.next(enrichedError);
  }

  AppException _mapDioExceptionToAppException(DioException err) {
    final response = err.response;
    final statusCode = response?.statusCode;

    // Network connection errors and timeouts
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'Connection timed out. Please check your internet connection.',
          code: 'CONNECTION_TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'Unable to reach Oversee server. Please check your network or server status.',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.cancel:
        return const NetworkException(
          message: 'Request was cancelled.',
          code: 'REQUEST_CANCELLED',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'Security certificate verification failed.',
          code: 'BAD_CERTIFICATE',
        );
      default:
        break;
    }

    // Extract error details from backend ErrorResponse
    String message = 'An unexpected error occurred. Please try again.';
    String code = 'UNKNOWN_ERROR';
    dynamic details;

    if (response?.data != null && response!.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('message') && data['message'] is String) {
        message = data['message'] as String;
      } else if (data.containsKey('detail')) {
        if (data['detail'] is String) {
          message = data['detail'] as String;
        } else if (data['detail'] is List && (data['detail'] as List).isNotEmpty) {
          // FastAPI standard validation error detail list
          final first = (data['detail'] as List).first;
          if (first is Map && first.containsKey('msg')) {
            message = first['msg'].toString();
          } else {
            message = data['detail'].toString();
          }
        }
      }

      if (data.containsKey('code') && data['code'] is String) {
        code = data['code'] as String;
      }
      if (data.containsKey('details')) {
        details = data['details'];
      }
    }

    switch (statusCode) {
      case 400:
      case 422:
        return ValidationException(
          message: message,
          code: code != 'UNKNOWN_ERROR' ? code : 'VALIDATION_ERROR',
          details: details,
          statusCode: statusCode,
        );
      case 401:
        return UnauthorizedException(
          message: message.isNotEmpty ? message : 'Session expired or unauthenticated.',
          code: code != 'UNKNOWN_ERROR' ? code : 'UNAUTHORIZED',
          details: details,
          statusCode: statusCode,
        );
      case 403:
        return ForbiddenException(
          message: message.isNotEmpty ? message : 'You do not have permission to perform this action.',
          code: code != 'UNKNOWN_ERROR' ? code : 'FORBIDDEN',
          details: details,
          statusCode: statusCode,
        );
      case 404:
        return NotFoundException(
          message: message.isNotEmpty ? message : 'Requested resource was not found.',
          code: code != 'UNKNOWN_ERROR' ? code : 'NOT_FOUND',
          details: details,
          statusCode: statusCode,
        );
      case 409:
        return ConflictException(
          message: message.isNotEmpty ? message : 'A conflict occurred with an existing resource.',
          code: code != 'UNKNOWN_ERROR' ? code : 'CONFLICT',
          details: details,
          statusCode: statusCode,
        );
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: message.isNotEmpty ? message : 'Internal server error occurred.',
            code: code != 'UNKNOWN_ERROR' ? code : 'INTERNAL_SERVER_ERROR',
            details: details,
            statusCode: statusCode,
          );
        }
        return AppException(
          message: message,
          code: code,
          details: details,
          statusCode: statusCode,
        );
    }
  }
}
