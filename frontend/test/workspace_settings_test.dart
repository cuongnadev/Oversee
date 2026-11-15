import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/workspace/application/workspace_settings_provider.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_member_model.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/workspace_settings_screen.dart';

class FakeWorkspaceSettingsRepository implements WorkspaceRepository {
  WorkspaceModel mockWorkspace = const WorkspaceModel(
    id: 'ws-test-1',
    name: 'Oversee Engineering',
    slug: 'oversee-eng',
    description: 'Engineering workspace',
    ownerId: 'user-owner-1',
    userRole: RoleType.owner,
  );

  List<WorkspaceMemberModel> mockMembers = [
    const WorkspaceMemberModel(
      id: 'mem-1',
      workspaceId: 'ws-test-1',
      userId: 'user-owner-1',
      role: RoleType.owner,
      user: UserModel(
        id: 'user-owner-1',
        email: 'owner@oversee.local',
        fullName: 'Alice Owner',
      ),
    ),
    const WorkspaceMemberModel(
      id: 'mem-2',
      workspaceId: 'ws-test-1',
      userId: 'user-member-2',
      role: RoleType.member,
      user: UserModel(
        id: 'user-member-2',
        email: 'bob@oversee.local',
        fullName: 'Bob Developer',
      ),
    ),
  ];

  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnDemoteLastOwner = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<WorkspaceModel> getWorkspace(String workspaceId, {String? currentUserId}) async {
    return mockWorkspace;
  }

  @override
  Future<List<WorkspaceMemberModel>> getWorkspaceMembers(String workspaceId) async {
    return mockMembers;
  }

  @override
  Future<WorkspaceModel> updateWorkspace(
    String workspaceId, {
    String? name,
    String? slug,
    String? description,
    String? currentUserId,
  }) async {
    if (shouldThrowOnUpdate) {
      throw const ValidationException(message: 'Slug already taken', code: 'SLUG_EXISTS');
    }
    mockWorkspace = mockWorkspace.copyWith(
      name: name ?? mockWorkspace.name,
      slug: slug ?? mockWorkspace.slug,
      description: description ?? mockWorkspace.description,
    );
    return mockWorkspace;
  }

  @override
  Future<WorkspaceMemberModel> addWorkspaceMember(
    String workspaceId, {
    String? userId,
    String? email,
    RoleType role = RoleType.member,
  }) async {
    final newMember = WorkspaceMemberModel(
      id: 'mem-${mockMembers.length + 1}',
      workspaceId: workspaceId,
      userId: userId ?? 'user-new',
      role: role,
      user: UserModel(
        id: userId ?? 'user-new',
        email: email ?? 'new@oversee.local',
        fullName: 'New Member',
      ),
    );
    mockMembers.add(newMember);
    return newMember;
  }

  @override
  Future<WorkspaceMemberModel> updateWorkspaceMemberRole(
    String workspaceId,
    String userId,
    RoleType role,
  ) async {
    if (shouldThrowOnDemoteLastOwner) {
      throw const ValidationException(
        message: 'Cannot demote the last owner of the workspace.',
        code: 'LAST_OWNER_DEMOTION',
      );
    }
    final index = mockMembers.indexWhere((m) => m.userId == userId);
    final updated = WorkspaceMemberModel(
      id: mockMembers[index].id,
      workspaceId: workspaceId,
      userId: userId,
      role: role,
      user: mockMembers[index].user,
    );
    mockMembers[index] = updated;
    return updated;
  }

  @override
  Future<void> removeWorkspaceMember(String workspaceId, String userId) async {
    mockMembers.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    // Soft deleted
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceSettingsNotifier Unit Tests', () {
    late FakeWorkspaceSettingsRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeWorkspaceSettingsRepository();
    });

    test('loadSettings accurately detects Owner role and populates members', () async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );

      await notifier.loadSettings();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.workspace?.name, 'Oversee Engineering');
      expect(notifier.state.currentUserRole, RoleType.owner);
      expect(notifier.state.isOwner, isTrue);
      expect(notifier.state.canManageMembers, isTrue);
      expect(notifier.state.members.length, 2);
    });

    test('loadSettings accurately detects Member role for regular users', () async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-member-2',
      );

      await notifier.loadSettings();

      expect(notifier.state.currentUserRole, RoleType.member);
      expect(notifier.state.isOwner, isFalse);
      expect(notifier.state.canManageMembers, isFalse);
    });

    test('updateWorkspace saves changes and updates state', () async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );

      await notifier.loadSettings();
      final success = await notifier.updateWorkspace(
        name: 'Updated Name',
        slug: 'updated-slug',
        description: 'New Description',
      );

      expect(success, isTrue);
      expect(notifier.state.workspace?.name, 'Updated Name');
      expect(notifier.state.successMessage, 'Workspace updated successfully.');
    });

    test('addMember invites new user and updates members count', () async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );

      await notifier.loadSettings();
      final success = await notifier.addMember(
        email: 'charlie@oversee.local',
        role: RoleType.admin,
      );

      expect(success, isTrue);
      expect(notifier.state.members.length, 3);
      expect(notifier.state.members.last.user?.email, 'charlie@oversee.local');
    });

    test('updateMemberRole catches cannot demote last owner backend error', () async {
      fakeRepo.shouldThrowOnDemoteLastOwner = true;

      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );

      await notifier.loadSettings();
      final success = await notifier.updateMemberRole('user-owner-1', RoleType.member);

      expect(success, isFalse);
      expect(notifier.state.errorMessage, 'Cannot demote the last owner of the workspace.');
    });

    test('removeMember removes member from list', () async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );

      await notifier.loadSettings();
      final success = await notifier.removeMember('user-member-2');

      expect(success, isTrue);
      expect(notifier.state.members.length, 1);
    });
  });

  group('WorkspaceSettingsScreen Widget Tests', () {
    late FakeWorkspaceSettingsRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeWorkspaceSettingsRepository();
    });

    testWidgets('renders general information form and members list', (WidgetTester tester) async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-owner-1',
      );
      await notifier.loadSettings();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(fakeRepo),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-owner-1', email: 'owner@oversee.local', fullName: 'Alice Owner'),
                  ),
                )),
            workspaceSettingsNotifierProvider('ws-test-1').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: WorkspaceSettingsScreen(workspaceId: 'ws-test-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form header and fields
      expect(find.text('Workspace Settings'), findsOneWidget);
      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('Oversee Engineering'), findsWidgets);
      expect(find.textContaining('@oversee-eng'), findsOneWidget);

      // Members section
      expect(find.text('Workspace Members (2)'), findsOneWidget);
      expect(find.text('Alice Owner'), findsOneWidget);
      expect(find.text('Bob Developer'), findsOneWidget);

      // Danger Zone is visible for Owner
      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('Delete Workspace'), findsOneWidget);
    });

    testWidgets('Danger Zone is hidden when current user is a Member', (WidgetTester tester) async {
      final notifier = WorkspaceSettingsNotifier(
        workspaceId: 'ws-test-1',
        repository: fakeRepo,
        currentUserId: 'user-member-2',
      );
      await notifier.loadSettings();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(fakeRepo),
            authNotifierProvider.overrideWith((ref) => AuthNotifier(
                  SecureStorageService(),
                  initialState: const AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(id: 'user-member-2', email: 'bob@oversee.local', fullName: 'Bob Developer'),
                  ),
                )),
            workspaceSettingsNotifierProvider('ws-test-1').overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: WorkspaceSettingsScreen(workspaceId: 'ws-test-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Danger Zone should NOT be present for regular members
      expect(find.text('Danger Zone'), findsNothing);
      expect(find.text('Delete Workspace'), findsNothing);
    });
  });
}
