import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/preferences_service.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/project_list_screen.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

class FakeProjectRepository implements ProjectRepository {
  List<ProjectModel> mockProjects = [
    ProjectModel(
      id: 'proj-1',
      workspaceId: 'ws-123',
      name: 'Oversee Mobile App',
      key: 'OMA',
      description: 'Flutter cross platform mobile app',
      memberCount: 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProjectModel(
      id: 'proj-2',
      workspaceId: 'ws-123',
      name: 'Backend Core Service',
      key: 'BCS',
      description: 'FastAPI and PostgreSQL microservices',
      memberCount: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  bool shouldThrowDuplicateKey = false;
  bool shouldThrowError = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectPageModel> listWorkspaceProjects(
    String workspaceId, {
    int page = 1,
    int pageSize = 20,
    bool includeArchived = false,
  }) async {
    if (shouldThrowError) {
      throw const ServerException(message: 'Failed to load projects');
    }
    return ProjectPageModel(
      items: mockProjects,
      total: mockProjects.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<ProjectModel> createProject(
    String workspaceId, {
    required String name,
    required String key,
    String? description,
  }) async {
    if (shouldThrowDuplicateKey) {
      throw ConflictException(
        message: "Project with key '$key' already exists in this workspace.",
        code: 'PROJECT_KEY_ALREADY_EXISTS',
      );
    }
    return ProjectModel(
      id: 'proj-${mockProjects.length + 1}',
      workspaceId: workspaceId,
      name: name,
      key: key,
      description: description,
      memberCount: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class FakeWorkspaceRepoForProjects implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    return [
      const WorkspaceModel(
        id: 'ws-123',
        name: 'Oversee Workspace',
        slug: 'oversee-ws',
        ownerId: 'user-1',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectModel Unit Tests', () {
    test('serializes and deserializes correctly', () {
      final json = {
        'id': 'proj-abc',
        'workspace_id': 'ws-123',
        'name': 'Design System',
        'key': 'DS',
        'description': 'UI Library',
        'member_count': 4,
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T12:00:00.000Z',
      };

      final project = ProjectModel.fromJson(json);
      expect(project.id, 'proj-abc');
      expect(project.name, 'Design System');
      expect(project.key, 'DS');
      expect(project.memberCount, 4);
      expect(project.isArchived, isFalse);

      final out = project.toJson();
      expect(out['key'], 'DS');
      expect(out['name'], 'Design System');
    });

    test('ProjectPageModel parses paginated payload', () {
      final json = {
        'items': [
          {'id': 'p-1', 'name': 'P1', 'key': 'P1', 'workspace_id': 'ws-1'},
          {'id': 'p-2', 'name': 'P2', 'key': 'P2', 'workspace_id': 'ws-1'},
        ],
        'total': 2,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };

      final page = ProjectPageModel.fromJson(json);
      expect(page.items.length, 2);
      expect(page.total, 2);
      expect(page.page, 1);
    });
  });

  group('Project Key Suggestion Generator Tests', () {
    test('generates acronym from multi-word names', () {
      expect(CreateProjectDialog.suggestKey('Mobile Application'), 'MA');
      expect(CreateProjectDialog.suggestKey('Backend Core Services'), 'BCS');
      expect(CreateProjectDialog.suggestKey('Team 04 Capstone Project'), 'T0CP');
    });

    test('generates 3-letter prefix for single words', () {
      expect(CreateProjectDialog.suggestKey('Oversee'), 'OVE');
      expect(CreateProjectDialog.suggestKey('Alpha'), 'ALP');
    });
  });

  group('ProjectListNotifier Unit Tests', () {
    late FakeProjectRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeProjectRepository();
    });

    test('loadProjects populates list from repository', () async {
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.projects.length, 2);
      expect(notifier.state.projects.first.key, 'OMA');
      expect(notifier.state.total, 2);
    });

    test('createProject adds new project to state immediately without reload', () async {
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      final created = await notifier.createProject(
        name: 'Web Portal',
        key: 'WP',
        description: 'Web dashboard',
      );

      expect(created, isNotNull);
      expect(notifier.state.projects.length, 3);
      expect(notifier.state.projects.first.name, 'Web Portal');
      expect(notifier.state.projects.first.key, 'WP');
      expect(notifier.state.total, 3);
    });

    test('createProject catches duplicate key 409 conflict and sets errorMessage', () async {
      fakeRepo.shouldThrowDuplicateKey = true;
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      final created = await notifier.createProject(
        name: 'Duplicate Project',
        key: 'OMA',
      );

      expect(created, isNull);
      expect(notifier.state.errorMessage, contains("Project with key 'OMA' already exists"));
    });

    test('search query filters projects locally', () async {
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      notifier.setSearchQuery('Backend');
      expect(notifier.state.filteredProjects.length, 1);
      expect(notifier.state.filteredProjects.first.key, 'BCS');

      notifier.setSearchQuery('OMA');
      expect(notifier.state.filteredProjects.length, 1);
      expect(notifier.state.filteredProjects.first.name, 'Oversee Mobile App');
    });
  });

  group('ProjectListScreen Widget Tests', () {
    late FakeProjectRepository fakeRepo;
    late FakeWorkspaceRepoForProjects fakeWsRepo;

    setUp(() {
      fakeRepo = FakeProjectRepository();
      fakeWsRepo = FakeWorkspaceRepoForProjects();
    });

    testWidgets('renders project card grid with keys and metadata', (WidgetTester tester) async {
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(fakeRepo),
            workspaceRepositoryProvider.overrideWithValue(fakeWsRepo),
            preferencesServiceProvider.overrideWithValue(PreferencesService()),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-1', email: 'user@oversee.local', fullName: 'Tester'),
                  ),
                )),
            projectListNotifierProvider('ws-123').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: ProjectListScreen(workspaceId: 'ws-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Projects Title
      expect(find.text('Projects'), findsWidgets);
      expect(find.text('2 total'), findsOneWidget);

      // Verify Project Keys & Names
      expect(find.text('OMA'), findsOneWidget);
      expect(find.text('Oversee Mobile App'), findsOneWidget);
      expect(find.text('5 members'), findsOneWidget);

      expect(find.text('BCS'), findsOneWidget);
      expect(find.text('Backend Core Service'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);

      // New Project Button
      expect(find.text('New Project'), findsOneWidget);
    });

    testWidgets('renders empty state when workspace has no projects', (WidgetTester tester) async {
      fakeRepo.mockProjects = [];
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(fakeRepo),
            workspaceRepositoryProvider.overrideWithValue(fakeWsRepo),
            preferencesServiceProvider.overrideWithValue(PreferencesService()),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-1', email: 'user@oversee.local', fullName: 'Tester'),
                  ),
                )),
            projectListNotifierProvider('ws-123').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: ProjectListScreen(workspaceId: 'ws-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Projects Found'), findsOneWidget);
      expect(find.text('Create First Project'), findsOneWidget);
    });

    testWidgets('tapping New Project opens CreateProjectDialog with key validation', (WidgetTester tester) async {
      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(fakeRepo),
            workspaceRepositoryProvider.overrideWithValue(fakeWsRepo),
            preferencesServiceProvider.overrideWithValue(PreferencesService()),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-1', email: 'user@oversee.local', fullName: 'Tester'),
                  ),
                )),
            projectListNotifierProvider('ws-123').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: ProjectListScreen(workspaceId: 'ws-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap New Project
      await tester.tap(find.text('New Project'));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Create Project'), findsWidgets);
      expect(find.text('Project Name'), findsOneWidget);
      expect(find.text('Project Key'), findsOneWidget);

      // Live identity preview updates when typing project name
      final nameField = find
          .descendant(
            of: find.byType(CreateProjectDialog),
            matching: find.byType(TextFormField),
          )
          .first;
      await tester.enterText(nameField, 'Platform Core');
      await tester.pump();
      expect(find.text('Issue prefix: PC-101 · Software project'), findsOneWidget);
    });

    testWidgets('switches between Grid view and List view cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = ProjectListNotifier(workspaceId: 'ws-123', repository: fakeRepo);
      await notifier.loadProjects();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(fakeRepo),
            workspaceRepositoryProvider.overrideWithValue(fakeWsRepo),
            preferencesServiceProvider.overrideWithValue(PreferencesService()),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-1', email: 'user@oversee.local', fullName: 'Tester'),
                  ),
                )),
            projectListNotifierProvider('ws-123').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: ProjectListScreen(workspaceId: 'ws-123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsNothing);
      expect(find.text('Oversee Mobile App'), findsOneWidget);
      expect(find.text('Backend Core Service'), findsOneWidget);
    });
  });
}
