import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/application/project_list_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/shared/layout/app_header.dart';

class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'fake-access-token';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh-token';
}

class _StubProjectRepository extends ProjectRepository {
  final List<ProjectModel> projects;

  _StubProjectRepository(this.projects) : super(ApiClient(Dio()));

  @override
  Future<ProjectPageModel> listWorkspaceProjects(
    String workspaceId, {
    int page = 1,
    int pageSize = 20,
    bool includeArchived = false,
  }) async {
    return ProjectPageModel(
      items: projects,
      total: projects.length,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );
  }
}

void main() {
  testWidgets('AppHeader displays resolved project name instead of raw project ID',
      (tester) async {
    const project = ProjectModel(
      id: 'proj-uuid-9999',
      workspaceId: 'ws-1',
      name: 'Oversee Platform',
      key: 'OVS',
    );
    final stubRepo = _StubProjectRepository([project]);

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              _FakeSecureStorage(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(
                  id: 'u-1',
                  email: 'vincentt@mail.com',
                  fullName: 'Vincent',
                ),
              ),
            ),
          ),
          projectListNotifierProvider('ws-1').overrideWith(
            (ref) => ProjectListNotifier(
              workspaceId: 'ws-1',
              repository: stubRepo,
              initialState: const ProjectListState(
                isLoading: false,
                projects: [project],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              workspaceId: 'ws-1',
              projectId: 'proj-uuid-9999',
              currentViewTitle: 'Overview',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oversee Platform'), findsOneWidget);
    expect(find.text('proj-uuid-9999'), findsNothing);
  });
}
