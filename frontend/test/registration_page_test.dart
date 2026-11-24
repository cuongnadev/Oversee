import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/auth/domain/token_model.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/main.dart';

class FakeRegisterAuthRepository implements AuthRepository {
  bool shouldFailWithConflict = false;
  bool shouldThrowGenericError = false;

  int registerCallCount = 0;
  String? lastFullName;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<TokenModel> login({required String email, required String password}) async {
    return const TokenModel(
      accessToken: 'test_token',
      refreshToken: 'test_refresh',
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
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    registerCallCount++;
    lastEmail = email;
    lastPassword = password;
    lastFullName = fullName;

    if (shouldFailWithConflict) {
      throw const ConflictException(
        message: 'Email is already registered.',
        code: 'EMAIL_ALREADY_EXISTS',
        statusCode: 409,
      );
    }

    if (shouldThrowGenericError) {
      throw const ServerException(
        message: 'Internal server error occurred.',
        code: 'INTERNAL_SERVER_ERROR',
        statusCode: 500,
      );
    }

    return UserModel(
      id: 'new-user-123',
      email: email,
      fullName: fullName,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> logout({required String refreshToken}) async {}
}

Widget _buildRegisterScreen({required FakeRegisterAuthRepository fakeRepo}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
      secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
    ],
    child: const MaterialApp(
      home: RegisterScreen(),
    ),
  );
}

Widget _buildFullApp({required FakeRegisterAuthRepository fakeRepo}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
      secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
    ],
    child: const OverseeApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Registration Page Form Validation Tests', () {
    testWidgets('Empty fields trigger validation error messages', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      expect(createButton, findsOneWidget);
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      expect(fakeRepo.registerCallCount, equals(0));
    });

    testWidgets('Invalid email format triggers format error', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'name@example.com');
      await tester.enterText(emailField, 'invalid-email-no-at-sign');

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(fakeRepo.registerCallCount, equals(0));
    });

    testWidgets('Password complexity rules are validated', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      final nameField = textFields.at(0);
      final emailField = textFields.at(1);
      final passwordField = textFields.at(2);
      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');

      await tester.enterText(nameField, 'Jane Doe');
      await tester.enterText(emailField, 'jane@example.com');

      // Test length < 8
      await tester.enterText(passwordField, 'Short1!');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // Test missing uppercase
      await tester.enterText(passwordField, 'lowercase123');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.text('Password must contain at least one uppercase letter'), findsOneWidget);

      // Test missing lowercase
      await tester.enterText(passwordField, 'UPPERCASE123');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.text('Password must contain at least one lowercase letter'), findsOneWidget);

      // Test missing digit
      await tester.enterText(passwordField, 'NoDigitsHere');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.text('Password must contain at least one digit'), findsOneWidget);

      expect(fakeRepo.registerCallCount, equals(0));
    });

    testWidgets('Password mismatch triggers error', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      final nameField = textFields.at(0);
      final emailField = textFields.at(1);
      final passwordField = textFields.at(2);
      final confirmPasswordField = textFields.at(3);

      await tester.enterText(nameField, 'Jane Doe');
      await tester.enterText(emailField, 'jane@example.com');
      await tester.enterText(passwordField, 'Password123');
      await tester.enterText(confirmPasswordField, 'DifferentPassword456');

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(fakeRepo.registerCallCount, equals(0));
    });
  });

  group('Registration API Integration & Error Handling Tests', () {
    testWidgets('Successful registration calls API, shows success snackbar, and redirects', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildFullApp(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      // Navigate from Login to Register
      final registerLink = find.widgetWithText(TextButton, 'Register');
      expect(registerLink, findsOneWidget);
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      expect(find.text('Create an Account'), findsOneWidget);

      // Fill valid registration fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Alice Wonderland');
      await tester.enterText(textFields.at(1), 'alice@example.com');
      await tester.enterText(textFields.at(2), 'AliceSecret123');
      await tester.enterText(textFields.at(3), 'AliceSecret123');

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Check API invocation
      expect(fakeRepo.registerCallCount, equals(1));
      expect(fakeRepo.lastFullName, equals('Alice Wonderland'));
      expect(fakeRepo.lastEmail, equals('alice@example.com'));
      expect(fakeRepo.lastPassword, equals('AliceSecret123'));

      // Check redirection to Login Screen
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Account created successfully! Please sign in.'), findsOneWidget);
    });

    testWidgets('Duplicate email (409 Conflict) displays error banner and field error', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository()..shouldFailWithConflict = true;
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Bob Builder');
      await tester.enterText(textFields.at(1), 'bob@example.com');
      await tester.enterText(textFields.at(2), 'BobBuilder123');
      await tester.enterText(textFields.at(3), 'BobBuilder123');

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.registerCallCount, equals(1));
      // Alert banner should appear with conflict message
      expect(find.text('Email is already registered.'), findsWidgets);
    });

    testWidgets('Server error displays error banner', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository()..shouldThrowGenericError = true;
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Charlie Brown');
      await tester.enterText(textFields.at(1), 'charlie@example.com');
      await tester.enterText(textFields.at(2), 'Charlie123');
      await tester.enterText(textFields.at(3), 'Charlie123');

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.registerCallCount, equals(1));
      expect(find.text('Internal server error occurred.'), findsOneWidget);
    });
  });

  group('Registration Modernist Layout & Responsive Tests', () {
    testWidgets('Mobile viewport renders register screen cleanly without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRegisterAuthRepository();
      await tester.pumpWidget(_buildRegisterScreen(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.text('Built for structured delivery.'), findsOneWidget);
      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Min 8 chars with uppercase, lowercase & number'), findsOneWidget);
    });
  });
}
