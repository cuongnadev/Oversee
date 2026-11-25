import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/token_model.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/main.dart';

class FakeAuthRepository implements AuthRepository {
  bool shouldFailWithInvalidCredentials = false;
  bool shouldFailWithInactive = false;
  bool shouldThrowGenericError = false;

  int loginCallCount = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<TokenModel> login({required String email, required String password}) async {
    loginCallCount++;
    lastEmail = email;
    lastPassword = password;

    if (shouldFailWithInvalidCredentials) {
      throw const UnauthorizedException(
        message: 'Invalid email or password.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    if (shouldFailWithInactive) {
      throw const UnauthorizedException(
        message: 'User account is inactive. Please contact support.',
        code: 'USER_INACTIVE',
      );
    }
    if (shouldThrowGenericError) {
      throw const ServerException(
        message: 'Server internal error.',
        code: 'INTERNAL_ERROR',
      );
    }

    return const TokenModel(
      accessToken: 'test_access_token_123',
      refreshToken: 'test_refresh_token_456',
    );
  }

  @override
  Future<UserModel> getCurrentUser() async {
    return const UserModel(
      id: 'user-uuid-1',
      email: 'demo@oversee.local',
      fullName: 'Demo User',
    );
  }

  @override
  Future<UserModel> register({required String email, required String password, required String fullName}) async {
    return UserModel(id: 'new-id', email: email, fullName: fullName);
  }

  @override
  Future<void> logout({required String refreshToken}) async {}
}

Widget _buildLoginApp({required FakeAuthRepository fakeRepo}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
      secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
    ],
    child: const OverseeApp(),
  );
}

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    fakeRepo = FakeAuthRepository();
  });

  group('Login Page Form Validation Tests', () {
    testWidgets('Empty fields trigger validation error messages', (WidgetTester tester) async {
      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      // Clear default demo credentials
      final emailFinder = find.widgetWithText(TextFormField, 'demo@oversee.local');
      final passFinder = find.widgetWithText(TextFormField, 'Password123!');
      await tester.enterText(emailFinder, '');
      await tester.enterText(passFinder, '');

      // Tap Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(fakeRepo.loginCallCount, 0);
    });

    testWidgets('Invalid email format triggers validation error', (WidgetTester tester) async {
      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final emailFinder = find.widgetWithText(TextFormField, 'demo@oversee.local');
      await tester.enterText(emailFinder, 'invalid-email-address');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(fakeRepo.loginCallCount, 0);
    });

    testWidgets('Tapping Register link navigates to /register', (WidgetTester tester) async {
      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create an Account'), findsOneWidget);
    });
  });

  group('Login API Integration & Error Handling Tests', () {
    testWidgets('Successful login saves tokens, updates state, and navigates to /workspaces',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      // Submit with valid credentials
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(fakeRepo.loginCallCount, 1);
      expect(fakeRepo.lastEmail, 'demo@oversee.local');
      expect(fakeRepo.lastPassword, 'Password123!');

      // Should have navigated to /workspaces
      expect(find.text('Your Workspaces'), findsOneWidget);
    });

    testWidgets('Invalid credentials (401) displays error banner', (WidgetTester tester) async {
      fakeRepo.shouldFailWithInvalidCredentials = true;

      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(fakeRepo.loginCallCount, 1);
      expect(find.text('Invalid email or password.'), findsOneWidget);

      // Dismiss error
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsNothing);
    });

    testWidgets('Inactive user account (401) displays specific message', (WidgetTester tester) async {
      fakeRepo.shouldFailWithInactive = true;

      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(fakeRepo.loginCallCount, 1);
      expect(find.text('User account is inactive. Please contact support.'), findsOneWidget);
    });
  });

  group('Login Modernist Layout & Responsive Tests', () {
    testWidgets('Desktop split layout displays hero editorial content and theme toggle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildLoginApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.text('Clarity across every sprint.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);

      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    });

    testWidgets('Mobile compact layout stacks cleanly without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clarity across every sprint.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Short split viewport and mobile notch + text scaling render without overflow',
        (WidgetTester tester) async {
      // Short landscape split window (e.g. tablet with soft keyboard)
      tester.view.physicalSize = const Size(900, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clarity across every sprint.'), findsOneWidget);

      // Mobile with Dynamic Island top inset + 1.4x accessibility text scale
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(top: 59.0);
      addTearDown(() => tester.view.resetViewPadding());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 59.0),
                textScaler: TextScaler.linear(1.4),
              ),
              child: LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
