import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/project/application/project_overview_provider.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/features/project/application/project_settings_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/project_overview_screen.dart';
import 'package:frontend/features/project/presentation/project_settings_screen.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';

class FakeProjectRepository implements ProjectRepository {
  ProjectModel mockProject = ProjectModel(
    id: 'proj-1',
    workspaceId: 'ws-1',
    name: 'Oversee Web App',
    key: 'OVS',
    description: 'Frontend and backend core application',
    memberCount: 2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  List<ProjectMemberModel> mockMembers = [
    const ProjectMemberModel(
      id: 'pmem-1',
      projectId: 'proj-1',
      userId: 'user-owner',
      role: RoleType.owner,
      user: UserModel(
        id: 'user-owner',
        email: 'owner@oversee.local',
        fullName: 'Alice Owner',
      ),
    ),
    const ProjectMemberModel(
      id: 'pmem-2',
      projectId: 'proj-1',
      userId: 'user-member',
      role: RoleType.member,
      user: UserModel(
        id: 'user-member',
        email: 'bob@oversee.local',
        fullName: 'Bob Dev',
      ),
    ),
  ];

  bool shouldThrowOnGet = false;
  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnAddMember = false;
  bool shouldThrowOnDemoteLastOwner = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    if (shouldThrowOnGet) {
      throw const AppException(message: 'Project not found');
    }
    return mockProject;
  }

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async {
    return List.from(mockMembers);
  }

  @override
  Future<ProjectModel> updateProject(
    String projectId, {
    String? name,
    String? key,
    String? description,
  }) async {
    if (shouldThrowOnUpdate) {
      throw const AppException(message: 'Project key already exists in workspace.');
    }
    mockProject = mockProject.copyWith(
      name: name ?? mockProject.name,
      key: key ?? mockProject.key,
      description: description ?? mockProject.description,
    );
    return mockProject;
  }

  @override
  Future<ProjectMemberModel> addProjectMember(
    String projectId, {
    String? userId,
    String? email,
    required RoleType role,
  }) async {
    if (shouldThrowOnAddMember) {
      throw const AppException(message: 'User must belong to workspace first.');
    }
    final newMember = ProjectMemberModel(
      id: 'pmem-new',
      projectId: projectId,
      userId: userId ?? 'user-new',
      role: role,
      user: UserModel(
        id: userId ?? 'user-new',
        email: email ?? 'new@oversee.local',
        fullName: 'New Member',
      ),
    );
    return newMember;
  }

  @override
  Future<ProjectMemberModel> updateProjectMemberRole(
    String projectId,
    String userId, {
    required RoleType role,
  }) async {
    if (shouldThrowOnDemoteLastOwner) {
      throw const AppException(message: 'Cannot demote the last owner of the project.');
    }
    final member = mockMembers.firstWhere((m) => m.userId == userId);
    return member.copyWith(role: role);
  }

  @override
  Future<void> removeProjectMember(String projectId, String userId) async {
    mockMembers.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<void> archiveProject(String projectId) async {
    mockProject = mockProject.copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<ProjectModel> restoreProject(String projectId) async {
    mockProject = mockProject.copyWith(clearDeletedAt: true);
    return mockProject;
  }

  @override
  Future<void> deleteProject(String projectId) async {
    mockProject = mockProject.copyWith(deletedAt: DateTime.now());
  }
}

class FakeSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String?> getAccessToken() async => 'mock-token';
  @override
  Future<String?> getRefreshToken() async => 'mock-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectMemberModel Unit Tests', () {
    test('serializes and deserializes correctly', () {
      final json = {
        'id': 'pmem-123',
        'project_id': 'proj-123',
        'user_id': 'user-123',
        'role': 'admin',
        'user': {
          'id': 'user-123',
          'email': 'admin@oversee.local',
          'full_name': 'Admin User',
          'is_active': true,
        },
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      };

      final model = ProjectMemberModel.fromJson(json);
      expect(model.id, equals('pmem-123'));
      expect(model.role, equals(RoleType.admin));
      expect(model.user?.fullName, equals('Admin User'));

      final outJson = model.toJson();
      expect(outJson['role'], equals('admin'));
      expect(outJson['user']['email'], equals('admin@oversee.local'));
    });

    test('copyWith produces equal object with updated fields', () {
      const model = ProjectMemberModel(
        id: 'pmem-1',
        projectId: 'proj-1',
        userId: 'u-1',
        role: RoleType.member,
      );

      final updated = model.copyWith(role: RoleType.admin);
      expect(updated.role, equals(RoleType.admin));
      expect(updated.id, equals('pmem-1'));
    });
  });

  group('ProjectOverviewNotifier Unit Tests', () {
    late FakeProjectRepository repo;

    setUp(() {
      repo = FakeProjectRepository();
    });

    test('loadProject populates project and detects current user role as owner', () async {
      final notifier = ProjectOverviewNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );

      await notifier.loadProject();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.project?.name, equals('Oversee Web App'));
      expect(notifier.state.currentUserRole, equals(RoleType.owner));
      expect(notifier.state.isOwner, isTrue);
      expect(notifier.state.canEdit, isTrue);
    });

    test('loadProject detects current user role as member', () async {
      final notifier = ProjectOverviewNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-member',
      );

      await notifier.loadProject();
      expect(notifier.state.currentUserRole, equals(RoleType.member));
      expect(notifier.state.isOwner, isFalse);
      expect(notifier.state.canEdit, isFalse);
    });

    test('loadProject handles error gracefully and sets errorMessage', () async {
      repo.shouldThrowOnGet = true;
      final notifier = ProjectOverviewNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );

      await notifier.loadProject();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, contains('Project not found'));
    });
  });

  group('ProjectSettingsNotifier Unit Tests', () {
    late FakeProjectRepository repo;

    setUp(() {
      repo = FakeProjectRepository();
    });

    test('loadSettings loads project and members', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );

      await notifier.loadSettings();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.members.length, equals(2));
      expect(notifier.state.canEditSettings, isTrue);
    });

    test('updateProject saves changes and updates state', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );
      await notifier.loadSettings();

      final success = await notifier.updateProject(
        name: 'Oversee Updated',
        key: 'OVU',
        description: 'New Description',
      );

      expect(success, isTrue);
      expect(notifier.state.project?.name, equals('Oversee Updated'));
      expect(notifier.state.project?.key, equals('OVU'));
    });

    test('addMember appends new member to state', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );
      await notifier.loadSettings();

      final success = await notifier.addMember(
        email: 'charlie@oversee.local',
        role: RoleType.member,
      );

      expect(success, isTrue);
      expect(notifier.state.members.length, equals(3));
      expect(notifier.state.members.last.user?.email, equals('charlie@oversee.local'));
    });

    test('updateMemberRole updates role of existing member in state', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );
      await notifier.loadSettings();

      final success = await notifier.updateMemberRole('user-member', RoleType.admin);
      expect(success, isTrue);
      final member = notifier.state.members.firstWhere((m) => m.userId == 'user-member');
      expect(member.role, equals(RoleType.admin));
    });

    test('archiveProject sets project deletedAt in state', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );
      await notifier.loadSettings();

      final success = await notifier.archiveProject();
      expect(success, isTrue);
      expect(notifier.state.project?.isArchived, isTrue);
    });

    test('restoreProject reactivates project in state', () async {
      final notifier = ProjectSettingsNotifier(
        projectId: 'proj-1',
        repository: repo,
        currentUserId: 'user-owner',
      );
      await notifier.loadSettings();
      await notifier.archiveProject();

      final success = await notifier.restoreProject();
      expect(success, isTrue);
      expect(notifier.state.project?.isArchived, isFalse);
    });
  });

  group('Project Navigation & Screen Widget Tests', () {
    late FakeProjectRepository repo;

    setUp(() {
      repo = FakeProjectRepository();
    });

    Widget createTestApp({
      required Widget child,
      String currentUserId = 'user-owner',
      RoleType userRole = RoleType.owner,
    }) {
      return ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repo),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          authNotifierProvider.overrideWith((ref) => AuthNotifier(
                FakeSecureStorageService(),
                initialState: AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(
                    id: currentUserId,
                    email: '$currentUserId@oversee.local',
                    fullName: 'Test User',
                  ),
                ),
              )),
          projectOverviewNotifierProvider('proj-1').overrideWith((ref) => ProjectOverviewNotifier(
                projectId: 'proj-1',
                repository: repo,
                currentUserId: currentUserId,
                initialState: ProjectOverviewState(
                  isLoading: false,
                  project: repo.mockProject,
                  members: repo.mockMembers,
                  currentUserRole: userRole,
                ),
              )),
          projectSettingsNotifierProvider('proj-1').overrideWith((ref) => ProjectSettingsNotifier(
                projectId: 'proj-1',
                repository: repo,
                currentUserId: currentUserId,
                initialState: ProjectSettingsState(
                  isLoading: false,
                  project: repo.mockProject,
                  members: repo.mockMembers,
                  currentUserRole: userRole,
                ),
              )),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('ProjectNavigationTabBar renders all tabs and marks activeTab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProjectNavigationTabBar(
              workspaceId: 'ws-1',
              projectId: 'proj-1',
              activeTab: 'overview',
            ),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Kanban Board'), findsOneWidget);
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('Sprint Planning'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('ProjectOverviewScreen renders project info, KPIs, and team members', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createTestApp(
          child: const ProjectOverviewScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oversee Web App'), findsWidgets);
      expect(find.text('OVS'), findsWidgets);
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('WORKSPACE OVERVIEW'), findsOneWidget);
      expect(find.text('Total Issues'), findsOneWidget);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Story Points'), findsOneWidget);
      expect(find.text('Sprint Velocity'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Team Members'), findsWidgets);
      expect(find.text('Alice Owner'), findsOneWidget);
      expect(find.text('Bob Dev'), findsOneWidget);
    });

    testWidgets('ProjectOverviewScreen displays archived banner when project is archived', (tester) async {
      repo.mockProject = repo.mockProject.copyWith(deletedAt: DateTime.now());
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createTestApp(
          child: const ProjectOverviewScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This project is currently archived.'), findsOneWidget);
      expect(find.text('Restore Project'), findsOneWidget);
    });

    testWidgets('ProjectSettingsScreen renders form, members, and danger zone for Owner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        createTestApp(
          child: const ProjectSettingsScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
          currentUserId: 'user-owner',
          userRole: RoleType.owner,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Add Member'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('Delete Project'), findsOneWidget);
    });

    testWidgets('ProjectSettingsScreen renders read-only notice for Viewer role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        createTestApp(
          child: const ProjectSettingsScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
          currentUserId: 'user-viewer',
          userRole: RoleType.viewer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('You have read-only access to this project'), findsOneWidget);
      expect(find.text('Danger Zone'), findsNothing);
    });
  });
}
