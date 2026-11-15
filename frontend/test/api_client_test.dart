import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/auth_interceptor.dart';
import 'package:frontend/core/network/error_interceptor.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';

/// Test HTTP adapter allowing simulated network responses without a live server.
class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(dynamic data, {int statusCode = 200}) {
    final text = jsonEncode(data);
    return ResponseBody.fromString(
      text,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late SecureStorageService storage;

  setUp(() {
    storage = SecureStorageService();
  });

  group('ApiClient Health Check & Request Methods', () {
    test('checkHealth calls GET /health successfully', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        expect(options.path, equals(ApiConstants.health));
        return MockHttpClientAdapter.jsonResponse({
          'status': 'ok',
          'app': 'Oversee API',
          'version': '1.0.0',
        });
      });

      final apiClient = ApiClient(dio);
      final health = await apiClient.checkHealth();

      expect(health['status'], equals('ok'));
      expect(health['app'], equals('Oversee API'));
    });
  });

  group('AuthInterceptor Token Attachment & Refresh Rotation', () {
    test('Attaches Authorization Bearer header to non-public endpoints', () async {
      await storage.saveTokens(
        accessToken: 'valid_access_token_123',
        refreshToken: 'valid_refresh_token_456',
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));

      String? capturedAuthHeader;
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        capturedAuthHeader = options.headers['Authorization'] as String?;
        return MockHttpClientAdapter.jsonResponse(<String, dynamic>{'data': <dynamic>[]});
      });

      dio.interceptors.add(
        AuthInterceptor(storage: storage, dio: dio, refreshDio: refreshDio),
      );

      final apiClient = ApiClient(dio);
      await apiClient.get<dynamic>('/workspaces');

      expect(capturedAuthHeader, equals('Bearer valid_access_token_123'));
    });

    test('Does not attach Authorization header to public endpoints like /health or /auth/login', () async {
      await storage.saveTokens(
        accessToken: 'valid_access_token_123',
        refreshToken: 'valid_refresh_token_456',
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));

      String? capturedAuthHeader;
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        capturedAuthHeader = options.headers['Authorization'] as String?;
        return MockHttpClientAdapter.jsonResponse({'status': 'ok'});
      });

      dio.interceptors.add(
        AuthInterceptor(storage: storage, dio: dio, refreshDio: refreshDio),
      );

      final apiClient = ApiClient(dio);
      await apiClient.get<dynamic>(ApiConstants.health);

      expect(capturedAuthHeader, isNull);
    });

    test('Performs Token Rotation on 401 and retries original request with new token', () async {
      await storage.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'valid_refresh_token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));

      int workspaceCallCount = 0;
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/workspaces')) {
          workspaceCallCount++;
          if (workspaceCallCount == 1) {
            // First attempt with expired token fails with 401
            return MockHttpClientAdapter.jsonResponse(
              {'code': 'UNAUTHORIZED', 'message': 'Token expired'},
              statusCode: 401,
            );
          } else {
            // Second attempt after token refresh succeeds
            expect(options.headers['Authorization'], equals('Bearer rotated_new_access_token'));
            return MockHttpClientAdapter.jsonResponse([
              {'id': 'ws-1', 'name': 'Oversee Workspace'},
            ]);
          }
        }
        return MockHttpClientAdapter.jsonResponse(<String, dynamic>{}, statusCode: 404);
      });

      refreshDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        expect(options.path, equals(ApiConstants.refresh));
        expect((options.data as Map)['refresh_token'], equals('valid_refresh_token'));
        return MockHttpClientAdapter.jsonResponse({
          'access_token': 'rotated_new_access_token',
          'refresh_token': 'rotated_new_refresh_token',
          'token_type': 'bearer',
        });
      });

      dio.interceptors.add(
        AuthInterceptor(storage: storage, dio: dio, refreshDio: refreshDio),
      );

      final apiClient = ApiClient(dio);
      final response = await apiClient.get<List<dynamic>>('/workspaces');

      expect(workspaceCallCount, equals(2));
      expect(response.statusCode, equals(200));
      expect(response.data?.length, equals(1));

      // Verify tokens in storage were updated
      final updatedAccessToken = await storage.getAccessToken();
      final updatedRefreshToken = await storage.getRefreshToken();
      expect(updatedAccessToken, equals('rotated_new_access_token'));
      expect(updatedRefreshToken, equals('rotated_new_refresh_token'));
    });

    test('Triggers onSessionExpired and clears tokens when refresh token fails with 401', () async {
      await storage.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'invalid_refresh_token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));

      bool sessionExpiredTriggered = false;

      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.jsonResponse(
          {'code': 'UNAUTHORIZED', 'message': 'Token expired'},
          statusCode: 401,
        );
      });

      refreshDio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.jsonResponse(
          {'code': 'UNAUTHORIZED', 'message': 'Refresh token revoked'},
          statusCode: 401,
        );
      });

      dio.interceptors.addAll([
        AuthInterceptor(
          storage: storage,
          dio: dio,
          refreshDio: refreshDio,
          onSessionExpired: () {
            sessionExpiredTriggered = true;
          },
        ),
        ErrorInterceptor(),
      ]);

      final apiClient = ApiClient(dio);

      await expectLater(
        () => apiClient.get<dynamic>('/workspaces'),
        throwsA(isA<UnauthorizedException>()),
      );

      // Verify session was cleared
      expect(sessionExpiredTriggered, isTrue);
      final remainingToken = await storage.getAccessToken();
      expect(remainingToken, isNull);
    });
  });

  group('ErrorInterceptor Backend Schema Translation', () {
    late Dio dio;
    late ApiClient apiClient;

    void setupErrorResponse(int statusCode, Map<String, dynamic> body) {
      dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return MockHttpClientAdapter.jsonResponse(body, statusCode: statusCode);
      });
      dio.interceptors.add(ErrorInterceptor());
      apiClient = ApiClient(dio);
    }

    test('Maps HTTP 400 to ValidationException with message and code', () async {
      setupErrorResponse(400, {
        'code': 'VALIDATION_ERROR',
        'message': 'Project key must be uppercase alphanumeric',
        'details': {'field': 'key'},
      });

      await expectLater(
        () => apiClient.post<dynamic>('/projects', data: {'key': 'lowercase'}),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', 'Project key must be uppercase alphanumeric')
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('Maps HTTP 403 to ForbiddenException', () async {
      setupErrorResponse(403, {
        'code': 'FORBIDDEN',
        'message': 'Requires PROJECT_DELETE permission',
      });

      await expectLater(
        () => apiClient.delete<dynamic>('/projects/123'),
        throwsA(
          isA<ForbiddenException>()
              .having((e) => e.message, 'message', 'Requires PROJECT_DELETE permission')
              .having((e) => e.code, 'code', 'FORBIDDEN'),
        ),
      );
    });

    test('Maps HTTP 404 to NotFoundException', () async {
      setupErrorResponse(404, {
        'code': 'NOT_FOUND',
        'message': 'Issue #999 was not found',
      });

      await expectLater(
        () => apiClient.get<dynamic>('/issues/999'),
        throwsA(
          isA<NotFoundException>()
              .having((e) => e.message, 'message', 'Issue #999 was not found')
              .having((e) => e.code, 'code', 'NOT_FOUND'),
        ),
      );
    });

    test('Maps HTTP 409 to ConflictException', () async {
      setupErrorResponse(409, {
        'code': 'PROJECT_KEY_ALREADY_EXISTS',
        'message': 'Project with key OVS already exists in workspace',
      });

      await expectLater(
        () => apiClient.post<dynamic>('/workspaces/1/projects', data: {'key': 'OVS'}),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.message, 'message', contains('already exists'))
              .having((e) => e.code, 'code', 'PROJECT_KEY_ALREADY_EXISTS'),
        ),
      );
    });

    test('Maps HTTP 500 to ServerException', () async {
      setupErrorResponse(500, {
        'code': 'INTERNAL_SERVER_ERROR',
        'message': 'Database connection failure',
      });

      await expectLater(
        () => apiClient.get<dynamic>('/projects'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.code, 'code', 'INTERNAL_SERVER_ERROR'),
        ),
      );
    });
  });
}
