import 'package:equatable/equatable.dart';

/// Base exception class for Oversee frontend application.
class AppException extends Equatable implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  final int? statusCode;

  const AppException({
    required this.message,
    this.code,
    this.details,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, code, details, statusCode];

  @override
  String toString() => 'AppException(code: $code, message: $message, statusCode: $statusCode)';
}

/// Thrown when input validation fails (HTTP 400 or 422).
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.details,
    super.statusCode = 400,
  });
}

/// Thrown when user is not authenticated or token is invalid/expired (HTTP 401).
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    super.code = 'UNAUTHORIZED',
    super.details,
    super.statusCode = 401,
  });
}

/// Thrown when user does not have permission to perform action (HTTP 403).
class ForbiddenException extends AppException {
  const ForbiddenException({
    required super.message,
    super.code = 'FORBIDDEN',
    super.details,
    super.statusCode = 403,
  });
}

/// Thrown when requested resource is not found (HTTP 404).
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code = 'NOT_FOUND',
    super.details,
    super.statusCode = 404,
  });
}

/// Thrown on network connection issues.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.details,
  });
}
