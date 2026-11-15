import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/token_model.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/sprint/presentation/kanban_board_screen.dart';
import 'package:frontend/main.dart';

class FakeSessionAuthRepository implements AuthRepository {
  bool shouldFailGetCurrentUser = false;
  int logoutCallCount = 0;
  String? lastRevokedRefreshToken;
  int getCurrentUserCallCount = 0;

  @override
  Future<TokenModel> login({required String email, required String password}) async {
    return const TokenModel(accessToken: 'access_123', refreshToken: 'refresh_456');
  }

  @override
  Future<UserModel> getCurrentUser() async {
    getCurrentUserCallCount++;
    if (shouldFailGetCurrentUser) {
      throw const UnauthorizedException(
        message: 'Token has expired or is invalid.',
        code: 'TOKEN_EXPIRED',
        statusCode: 401,
      );
    }
    return const UserModel(
      id: 'usr-42',
      email: 'cuong@oversee.local',
      fullName: 'Cuong Nguyen',
      isActive: true,
    );
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return UserModel(id: 'usr-new', email: email, fullName: fullName);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCallCount++;
    lastRevokedRefreshToken = refreshToken;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Session Restoration Tests', () {
    test('checkAuthStatus transitions to unauthenticated when storage is empty', () async {
      final storage = SecureStorageService();
      final fakeRepo = FakeSessionAuthRepository();
      final notifier = AuthNotifier(
        storage,
        repository: fakeRepo,
        initialState: const AuthState(status: AuthStatus.initial),
      );

      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
    });

    test('checkAuthStatus restores user profile when valid token exists in storage', () async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'valid_jwt_token', refreshToken: 'valid_refresh_token');

      final fakeRepo = FakeSessionAuthRepository();
      final notifier = AuthNotifier(
        storage,
        repository: fakeRepo,
        initialState: const AuthState(status: AuthStatus.initial),
      );

      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user?.email, equals('cuong@oversee.local'));
      expect(notifier.state.user?.fullName, equals('Cuong Nguyen'));
      expect(fakeRepo.getCurrentUserCallCount, equals(1));
    });

    test('checkAuthStatus clears storage and logs out when token is expired or revoked', () async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'expired_token', refreshToken: 'expired_refresh');

      final fakeRepo = FakeSessionAuthRepository()..shouldFailGetCurrentUser = true;
      final notifier = AuthNotifier(
        storage,
        repository: fakeRepo,
        initialState: const AuthState(status: AuthStatus.initial),
      );

      await notifier.checkAuthStatus();

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
      expect(fakeRepo.logoutCallCount, equals(1));
      expect(fakeRepo.lastRevokedRefreshToken, equals('expired_refresh'));
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });

  group('Logout Flow Tests', () {
    test('logout revokes refresh token on backend and clears local storage', () async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'acc_token', refreshToken: 'ref_token_to_revoke');

      final fakeRepo = FakeSessionAuthRepository();
      final notifier = AuthNotifier(
        storage,
        repository: fakeRepo,
        initialState: const AuthState(status: AuthStatus.authenticated, accessToken: 'acc_token'),
      );

      await notifier.logout();

      expect(fakeRepo.logoutCallCount, equals(1));
      expect(fakeRepo.lastRevokedRefreshToken, equals('ref_token_to_revoke'));
      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    testWidgets('Logging out on protected page redirects cleanly to /login', (tester) async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'acc_token', refreshToken: 'ref_token');

      final fakeRepo = FakeSessionAuthRepository();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(storage),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const OverseeApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should be on /workspaces because session was restored
      expect(find.text('Your Workspaces'), findsOneWidget);

      // Trigger logout
      await capturedRef.read(authNotifierProvider.notifier).logout();
      await tester.pumpAndSettle();

      // Must be redirected to /login
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Your Workspaces'), findsNothing);
    });
  });

  group('Protected Route Guards Tests', () {
    testWidgets('Authenticated user visiting /login or /register is redirected to /workspaces', (tester) async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'token_123', refreshToken: 'ref_123');

      final fakeRepo = FakeSessionAuthRepository();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(storage),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const OverseeApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try navigating to /login
      final router = capturedRef.read(appRouterProvider);
      router.go(AppRoutes.login);
      await tester.pumpAndSettle();

      // Guard should redirect back to /workspaces
      expect(find.text('Your Workspaces'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);

      // Try navigating to /register
      router.go(AppRoutes.register);
      await tester.pumpAndSettle();

      // Guard should redirect back to /workspaces
      expect(find.text('Your Workspaces'), findsOneWidget);
      expect(find.text('Create an Account'), findsNothing);
    });

    testWidgets('Deep linking to board preserves location when authenticated', (tester) async {
      final storage = SecureStorageService();
      await storage.saveTokens(accessToken: 'token_123', refreshToken: 'ref_123');

      final fakeRepo = FakeSessionAuthRepository();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(storage),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const OverseeApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = capturedRef.read(appRouterProvider);
      router.go(AppRoutes.projectBoardPath('ws-production', 'proj-alpha'));
      await tester.pumpAndSettle();

      expect(find.byType(KanbanBoardScreen), findsOneWidget);
    });
  });
}
