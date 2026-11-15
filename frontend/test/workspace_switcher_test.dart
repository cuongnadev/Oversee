import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/preferences_service.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  List<WorkspaceModel> workspaces = [];
  bool shouldThrowError = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    if (shouldThrowError) {
      throw Exception('Network connection error');
    }
    return workspaces;
  }

  @override
  Future<WorkspaceModel> createWorkspace({
    required String name,
    required String slug,
    String? description,
    String? currentUserId,
  }) async {
    if (shouldThrowError) {
      throw Exception('Failed to create workspace');
    }
    return WorkspaceModel(
      id: 'ws-new-id',
      name: name,
      slug: slug,
      description: description,
      ownerId: currentUserId ?? 'user-1',
      userRole: RoleType.owner,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkspaceModel Unit Tests', () {
    test('serializes and deserializes correctly', () {
      final json = {
        'id': 'ws-123',
        'name': 'Oversee Team',
        'slug': 'oversee-team',
        'description': 'Main workspace',
        'owner_id': 'user-1',
        'role': 'admin',
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T12:00:00.000Z',
      };

      final model = WorkspaceModel.fromJson(json);
      expect(model.id, 'ws-123');
      expect(model.name, 'Oversee Team');
      expect(model.slug, 'oversee-team');
      expect(model.description, 'Main workspace');
      expect(model.userRole, RoleType.admin);

      final outputJson = model.toJson();
      expect(outputJson['id'], 'ws-123');
      expect(outputJson['role'], 'admin');
    });

    test('automatically resolves OWNER role if currentUserId matches owner_id', () {
      final json = {
        'id': 'ws-123',
        'name': 'Oversee Team',
        'slug': 'oversee-team',
        'owner_id': 'user-current',
      };

      final model = WorkspaceModel.fromJson(json, currentUserId: 'user-current');
      expect(model.userRole, RoleType.owner);
    });
  });

  group('PreferencesService Workspace Tests', () {
    test('persists and restores lastWorkspaceId', () async {
      final service = PreferencesService();
      await service.saveLastWorkspaceId('ws-persisted-99');
      final restored = await service.getLastWorkspaceId();
      expect(restored, 'ws-persisted-99');

      await service.clearLastWorkspaceId();
      final cleared = await service.getLastWorkspaceId();
      expect(cleared, isNull);
    });
  });

  group('WorkspaceNotifier Tests', () {
    late FakeWorkspaceRepository fakeRepo;
    late PreferencesService prefsService;

    setUp(() {
      fakeRepo = FakeWorkspaceRepository();
      prefsService = PreferencesService();

      fakeRepo.workspaces = [
        const WorkspaceModel(
          id: 'ws-1',
          name: 'Workspace Alpha',
          slug: 'ws-alpha',
          ownerId: 'user-1',
          userRole: RoleType.owner,
        ),
        const WorkspaceModel(
          id: 'ws-2',
          name: 'Workspace Beta',
          slug: 'ws-beta',
          ownerId: 'user-2',
          userRole: RoleType.member,
        ),
      ];
    });

    test('loads workspaces and auto-selects first if no preference', () async {
      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );

      await notifier.loadWorkspaces();
      expect(notifier.state.workspaces.length, 2);
      expect(notifier.state.selectedWorkspace?.id, 'ws-1');
    });

    test('loads workspaces and restores saved preference', () async {
      await prefsService.saveLastWorkspaceId('ws-2');

      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );

      await notifier.loadWorkspaces();
      expect(notifier.state.selectedWorkspace?.id, 'ws-2');
    });

    test('switching workspace updates state and persists ID', () async {
      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );

      await notifier.loadWorkspaces();
      expect(notifier.state.selectedWorkspace?.id, 'ws-1');

      await notifier.selectWorkspace('ws-2');
      expect(notifier.state.selectedWorkspace?.id, 'ws-2');

      final saved = await prefsService.getLastWorkspaceId();
      expect(saved, 'ws-2');
    });

    test('creating workspace adds to list and marks as active', () async {
      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );

      await notifier.loadWorkspaces();
      final created = await notifier.createWorkspace(
        name: 'Workspace Gamma',
        slug: 'ws-gamma',
        description: 'New team workspace',
      );

      expect(created, isNotNull);
      expect(notifier.state.workspaces.length, 3);
      expect(notifier.state.selectedWorkspace?.name, 'Workspace Gamma');

      final saved = await prefsService.getLastWorkspaceId();
      expect(saved, 'ws-new-id');
    });
  });

  group('WorkspaceSwitcherDropdown Widget Tests', () {
    late FakeWorkspaceRepository fakeRepo;
    late PreferencesService prefsService;

    setUp(() {
      fakeRepo = FakeWorkspaceRepository();
      prefsService = PreferencesService();

      fakeRepo.workspaces = [
        const WorkspaceModel(
          id: 'ws-1',
          name: 'Workspace Alpha',
          slug: 'ws-alpha',
          ownerId: 'user-1',
          userRole: RoleType.owner,
        ),
        const WorkspaceModel(
          id: 'ws-2',
          name: 'Workspace Beta',
          slug: 'ws-beta',
          ownerId: 'user-2',
          userRole: RoleType.admin,
        ),
      ];
    });

    testWidgets('renders active workspace name and role badge', (WidgetTester tester) async {
      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );
      await notifier.loadWorkspaces();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(fakeRepo),
            preferencesServiceProvider.overrideWithValue(prefsService),
            workspaceNotifierProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: WorkspaceSwitcherDropdown(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Workspace Alpha'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('tapping dropdown opens bottom sheet with all workspaces and create button',
        (WidgetTester tester) async {
      final notifier = WorkspaceNotifier(
        repository: fakeRepo,
        prefsService: prefsService,
        currentUserId: 'user-1',
      );
      await notifier.loadWorkspaces();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(fakeRepo),
            preferencesServiceProvider.overrideWithValue(prefsService),
            workspaceNotifierProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: WorkspaceSwitcherDropdown(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the switcher
      await tester.tap(find.byType(WorkspaceSwitcherDropdown));
      await tester.pumpAndSettle();

      // Bottom sheet header
      expect(find.text('Switch Workspace'), findsOneWidget);
      // Both workspaces displayed
      expect(find.text('Workspace Alpha'), findsWidgets);
      expect(find.text('Workspace Beta'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);

      // Create action
      expect(find.text('Create Workspace'), findsOneWidget);
    });
  });
}
