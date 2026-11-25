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
import 'package:frontend/features/profile/presentation/profile_dialog.dart';

class _FakeIssueRepo implements IssueRepository {
  final IssuePageModel issuesPage;
  _FakeIssueRepo(this.issuesPage);

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
  }) async =>
      Future.value(issuesPage);
}

IssueModel _issue({
  required String id,
  required int issueNumber,
  required String assigneeId,
  DateTime? updatedAt,
}) =>
    IssueModel(
      id: id,
      projectId: 'proj-1',
      issueNumber: issueNumber,
      title: 'Task $issueNumber',
      reporterId: 'u-1',
      assigneeId: assigneeId,
      updatedAt: updatedAt,
      status: IssueStatus.done,
    );

const _user = UserModel(
  id: 'u-1',
  email: 'dev@oversee.local',
  fullName: 'Dev User',
);

Widget _buildDialogApp({required IssuePageModel page, String? projectId}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => AuthNotifier(
          SecureStorageService(),
          initialState: const AuthState(
            status: AuthStatus.authenticated,
            user: _user,
          ),
        ),
      ),
      issueRepositoryProvider.overrideWithValue(_FakeIssueRepo(page)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ProfileDialog(projectId: projectId),
      ),
    ),
  );
}

void main() {
  testWidgets('renders profile header, finished-count stats, and streak heatmap', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final page = IssuePageModel(
      items: [
        _issue(id: 'i-1', issueNumber: 1, assigneeId: 'u-1', updatedAt: now),
        _issue(id: 'i-2', issueNumber: 2, assigneeId: 'u-1', updatedAt: now),
      ],
      total: 2,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );

    await tester.pumpWidget(_buildDialogApp(page: page, projectId: 'proj-1'));
    await tester.pumpAndSettle();

    expect(find.text('Dev User').evaluate(), isNotEmpty);
    expect(find.text('dev@oversee.local').evaluate(), isNotEmpty);
    expect(find.text('2 finished'), findsOneWidget);
    expect(find.text('Streak Heatmap').evaluate(), isNotEmpty);
    expect(find.text('Theme Color'), findsOneWidget);
  });

  testWidgets('shows empty state when user has no finished tasks', (WidgetTester tester) async {
    final page = IssuePageModel(
      items: [
        _issue(id: 'i-1', issueNumber: 1, assigneeId: 'u-2', updatedAt: DateTime.now()),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );

    await tester.pumpWidget(_buildDialogApp(page: page, projectId: 'proj-1'));
    await tester.pumpAndSettle();

    expect(find.text('Dev User').evaluate(), isNotEmpty);
    expect(find.text('No finished tasks yet.'), findsOneWidget);
    expect(find.text('0 finished'), findsOneWidget);
  });
}
