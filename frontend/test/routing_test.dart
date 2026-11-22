import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/issue/presentation/backlog_screen.dart';
import 'package:frontend/features/project/presentation/create_project_screen.dart';
import 'package:frontend/features/project/presentation/project_feature_empty_screen.dart';
import 'package:frontend/features/sprint/presentation/kanban_board_screen.dart';
import 'package:frontend/features/workspace/presentation/create_workspace_screen.dart';
import 'package:frontend/shared/widgets/app_empty_state.dart';
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
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              (ref) => AuthNotifier(
                SecureStorageService(),
                initialState: const AuthState(status: AuthStatus.unauthenticated),
              ),
            ),
          ],
          child: const OverseeApp(),
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
      expect(find.text('New Workspace'), findsOneWidget);
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

      expect(find.byType(KanbanBoardScreen), findsOneWidget);
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

      expect(find.byType(BacklogScreen), findsOneWidget);
      expect(find.text('Product Backlog'), findsWidgets);
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

    testWidgets('Dedicated /workspaces/new and /workspaces/:id/projects/new routes resolve cleanly',
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
      router.go(AppRoutes.workspaceCreate);
      await tester.pumpAndSettle();
      expect(find.byType(CreateWorkspaceScreen), findsOneWidget);
      expect(find.text('Create a Workspace'), findsOneWidget);

      router.go(AppRoutes.workspaceProjectCreatePath('ws-team4'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateProjectScreen), findsOneWidget);
      expect(find.text('Create a Project'), findsOneWidget);
    });

    testWidgets('Every additional Figma sidebar route renders its own separated empty-state screen',
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
      final additionalRoutes = <(String, String)>[
        (AppRoutes.projectInboxPath('ws-1', 'proj-1'), 'Your Inbox is Clear'),
        (AppRoutes.projectMyTasksPath('ws-1', 'proj-1'), 'No Tasks Assigned Yet'),
        (AppRoutes.projectRoadmapPath('ws-1', 'proj-1'), 'No Roadmap Milestones Yet'),
        (AppRoutes.projectTimelinePath('ws-1', 'proj-1'), 'Timeline is Empty'),
        (AppRoutes.projectCalendarPath('ws-1', 'proj-1'), 'No Scheduled Dates'),
        (AppRoutes.projectInitiativesPath('ws-1', 'proj-1'), 'No Initiatives or Epics'),
        (AppRoutes.projectDocumentsPath('ws-1', 'proj-1'), 'No Documents Yet'),
        (AppRoutes.projectReportsPath('ws-1', 'proj-1'), 'No Saved Reports Yet'),
        (AppRoutes.projectAiAssistantPath('ws-1', 'proj-1'), 'AI Assistant Ready Soon'),
        (AppRoutes.projectAutoSchedulePath('ws-1', 'proj-1'), 'No Auto-Schedule Rules Configured'),
        (AppRoutes.projectMembersPath('ws-1', 'proj-1'), 'Dedicated Members Directory'),
        (AppRoutes.projectNotificationsPath('ws-1', 'proj-1'), 'No Notification Rules Yet'),
        (AppRoutes.projectIntegrationsPath('ws-1', 'proj-1'), 'No Integrations Connected'),
        (AppRoutes.projectApiDocsPath('ws-1', 'proj-1'), 'API Reference Portal'),
        (AppRoutes.projectDeveloperPath('ws-1', 'proj-1'), 'No Developer Tokens Yet'),
      ];

      for (final (path, expectedEmptyTitle) in additionalRoutes) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(ProjectFeatureEmptyScreen), findsOneWidget, reason: 'Route $path');
        expect(find.byType(AppEmptyState), findsOneWidget, reason: 'Route $path');
        expect(find.text(expectedEmptyTitle), findsOneWidget, reason: 'Route $path');
      }
    });
  });
}
