import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/calendar_screen.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

class _FakeIssueRepo implements IssueRepository {
  List<IssueModel> issues;
  _FakeIssueRepo(this.issues);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssuePageModel> listProjectIssues(
    String projectId, {
    int page = 1,
    int pageSize = 100,
    String? search,
    IssuePriority? priority,
    IssueType? type,
    IssueStatus? status,
    String? sort,
  }) async {
    return IssuePageModel(
      items: List.of(issues),
      total: issues.length,
      page: 1,
      pageSize: pageSize,
      totalPages: 1,
    );
  }
}

class _FakeProjectRepo implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async => const ProjectModel(
        id: 'proj-1',
        workspaceId: 'ws-1',
        name: 'Platform v2.0',
        key: 'PLT',
      );

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async => const [];
}

class _FakeSprintRepo implements SprintRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SprintModel>> listProjectSprints(String projectId, {SprintStatus? status}) async =>
      const [];
}

class _FakeWorkspaceRepo implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async => const [];
}

class _FakeStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> getAccessToken() async => 'tok';

  @override
  Future<String?> getRefreshToken() async => 'ref';
}

void main() {
  testWidgets('CalendarScreen renders monthly grid, scheduled issue, and unscheduled sidebar',
      (tester) async {
    final now = DateTime.now();
    final repo = _FakeIssueRepo([
      IssueModel(
        id: 'i-1',
        projectId: 'proj-1',
        issueNumber: 103,
        title: 'API Sprint Endpoint',
        status: IssueStatus.inReview,
        priority: IssuePriority.high,
        reporterId: 'u-1',
        endDate: DateTime(now.year, now.month, now.day),
      ),
      const IssueModel(
        id: 'i-2',
        projectId: 'proj-1',
        issueNumber: 116,
        title: 'Onboarding Guide',
        status: IssueStatus.backlog,
        priority: IssuePriority.medium,
        reporterId: 'u-1',
      ),
    ]);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          issueRepositoryProvider.overrideWithValue(repo),
          projectRepositoryProvider.overrideWithValue(_FakeProjectRepo()),
          sprintRepositoryProvider.overrideWithValue(_FakeSprintRepo()),
          workspaceRepositoryProvider.overrideWithValue(_FakeWorkspaceRepo()),
          secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              _FakeStorage(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(id: 'u-1', email: 'dev@oversee.local', fullName: 'Minh Tuan'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CalendarScreen(workspaceId: 'ws-1', projectId: 'proj-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('API Sprint Endpoint'), findsOneWidget);
    expect(find.text('Unscheduled'), findsOneWidget);
    expect(find.text('Onboarding Guide'), findsOneWidget);
    expect(find.text('PLT-116'), findsOneWidget);
  });
}
