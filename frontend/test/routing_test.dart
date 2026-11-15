import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('GoRouter & Route Guards Tests', () {
    testWidgets('Unauthenticated user is redirected to /login when accessing protected routes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: OverseeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Signing in updates auth state and redirects to /workspaces',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: OverseeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In button on login screen
      final signInBtn = find.text('Sign In');
      expect(signInBtn, findsOneWidget);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Expect Workspaces screen elements to be shown
      expect(find.text('Your Workspaces'), findsOneWidget);
      expect(find.text('Team 04 - Oversee'), findsOneWidget);
    });

    testWidgets('Deep linking to project board loads correctly when authenticated',
        (WidgetTester tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    accessToken: 'mock_token',
                  ),
                )),
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

      // Navigate to project board route
      final router = capturedRef.read(appRouterProvider);
      router.go(AppRoutes.projectBoardPath('ws-team4', 'proj-oversee'));
      await tester.pumpAndSettle();

      expect(find.text('Kanban Board (proj-oversee)'), findsOneWidget);
      expect(find.text('Workspace: ws-team4'), findsOneWidget);
    });

    testWidgets('Deep linking to project backlog loads correctly',
        (WidgetTester tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    accessToken: 'mock_token',
                  ),
                )),
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
      router.go(AppRoutes.projectBacklogPath('ws-team4', 'proj-oversee'));
      await tester.pumpAndSettle();

      expect(find.text('Product Backlog (proj-oversee)'), findsOneWidget);
    });

    testWidgets('Accessing invalid URL triggers 404 NotFoundScreen',
        (WidgetTester tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    accessToken: 'mock_token',
                  ),
                )),
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
      router.go('/unknown/invalid/path');
      await tester.pumpAndSettle();

      expect(find.text('404'), findsOneWidget);
      expect(find.text('Page Not Found'), findsOneWidget);
      expect(find.text('Back to Workspaces'), findsOneWidget);
    });
  });
}
