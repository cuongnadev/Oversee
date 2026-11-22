import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/document/data/document_repository.dart';
import 'package:frontend/features/document/domain/document_model.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/shared/layout/app_header.dart';
import 'package:frontend/shared/widgets/quick_create_dialog.dart';

class _FakeIssueRepo implements IssueRepository {
  final List<Map<String, dynamic>> created = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssueModel> createIssue(
    String projectId, {
    required String title,
    String? description,
    IssueType type = IssueType.task,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
  }) async {
    created.add({
      'projectId': projectId,
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      'estimate': estimate,
    });
    return IssueModel(
      id: 'iss-new',
      projectId: projectId,
      issueNumber: 1,
      title: title,
      type: type,
      priority: priority,
      reporterId: 'u-1',
    );
  }
}

class _FakeSprintRepo implements SprintRepository {
  final List<Map<String, dynamic>> created = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SprintModel> createSprint(
    String projectId, {
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
  }) async {
    created.add({
      'projectId': projectId,
      'name': name,
      'goal': goal,
      'startDate': startDate,
      'endDate': endDate,
      'capacity': capacity,
    });
    return SprintModel(
      id: 'sp-new',
      projectId: projectId,
      name: name,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
      capacity: capacity,
    );
  }
}

class _FakeDocumentRepo implements DocumentRepository {
  final List<Map<String, dynamic>> created = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<DocumentModel> createDocument(
    String projectId, {
    required String title,
    String? content,
  }) async {
    created.add({'projectId': projectId, 'title': title, 'content': content});
    return DocumentModel(
      id: 'doc-new',
      projectId: projectId,
      title: title,
      content: content,
      authorId: 'u-1',
    );
  }
}

class _FakeWorkspaceRepo implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async => const [];
}

class _FakeSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> getAccessToken() async => 'tok';

  @override
  Future<String?> getRefreshToken() async => 'ref';
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('AppHeader Responsive & Quick Create Dropdown Tests', () {
    Widget wrapHeader(Size size, {_FakeIssueRepo? issueRepo, _FakeSprintRepo? sprintRepo, _FakeDocumentRepo? docRepo}) {
      return ProviderScope(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(_FakeWorkspaceRepo()),
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorage()),
          if (issueRepo != null) issueRepositoryProvider.overrideWithValue(issueRepo),
          if (sprintRepo != null) sprintRepositoryProvider.overrideWithValue(sprintRepo),
          if (docRepo != null) documentRepositoryProvider.overrideWithValue(docRepo),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              _FakeSecureStorage(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(id: 'u-1', email: 'dev@oversee.local', fullName: 'Minh Tuan'),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: const Scaffold(
              appBar: AppHeader(
                workspaceId: 'ws-1',
                projectId: 'proj-1',
                currentViewTitle: 'Overview',
              ),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    testWidgets('AppHeader renders without overflow on Desktop, Tablet, and Mobile', (tester) async {
      for (final size in const [Size(1280, 800), Size(768, 800), Size(360, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapHeader(size));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Quick Create'), findsOneWidget);
        expect(find.byTooltip('Seed Color & Theme'), findsOneWidget);
        expect(find.byTooltip('User Profile'), findsOneWidget);
      }
    });

    testWidgets('Quick Create dropdown lists Issue, Epic, Sprint, Document', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapHeader(const Size(1280, 800)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quick Create'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsOneWidget);
      expect(find.text('Epic'), findsOneWidget);
      expect(find.text('Sprint'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
    });
  });

  group('QuickCreateDialog Validation & Submission Tests', () {
    testWidgets('validates and creates Issue, Epic, Sprint, and Document', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final issueRepo = _FakeIssueRepo();
      final sprintRepo = _FakeSprintRepo();
      final docRepo = _FakeDocumentRepo();

      Future<void> openDialog(QuickCreateEntityType type) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              issueRepositoryProvider.overrideWithValue(issueRepo),
              sprintRepositoryProvider.overrideWithValue(sprintRepo),
              documentRepositoryProvider.overrideWithValue(docRepo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => QuickCreateDialog.show(
                      ctx,
                      projectId: 'proj-1',
                      initialType: type,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      // 1. Issue validation + creation
      await openDialog(QuickCreateEntityType.issue);
      await tester.tap(find.text('Create Issue'));
      await tester.pumpAndSettle();
      expect(find.text('Issue title is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Fix login race condition');
      await tester.enterText(find.byType(TextFormField).last, '-5');
      await tester.tap(find.text('Create Issue'));
      await tester.pumpAndSettle();
      expect(find.text('Story points cannot be negative'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, '3');
      await tester.tap(find.text('Create Issue'));
      await tester.pumpAndSettle();
      expect(issueRepo.created.length, 1);
      expect(issueRepo.created.first['type'], IssueType.task);
      expect(issueRepo.created.first['estimate'], 3.0);

      // 2. Epic creation
      await openDialog(QuickCreateEntityType.epic);
      await tester.enterText(find.byType(TextFormField).first, 'Q4 Revamp');
      await tester.tap(find.text('Create Epic'));
      await tester.pumpAndSettle();
      expect(issueRepo.created.length, 2);
      expect(issueRepo.created.last['type'], IssueType.epic);

      // 3. Sprint validation + creation
      await openDialog(QuickCreateEntityType.sprint);
      await tester.tap(find.text('Create Sprint'));
      await tester.pumpAndSettle();
      expect(find.text('Sprint name is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Sprint 4');
      await tester.tap(find.text('Create Sprint'));
      await tester.pumpAndSettle();
      expect(sprintRepo.created.length, 1);
      expect(sprintRepo.created.first['name'], 'Sprint 4');

      // 4. Document validation + creation
      await openDialog(QuickCreateEntityType.document);
      await tester.tap(find.text('Create Document'));
      await tester.pumpAndSettle();
      expect(find.text('Document title is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'API RFC');
      await tester.enterText(find.byType(TextFormField).at(1), '# API Design');
      await tester.tap(find.text('Create Document'));
      await tester.pumpAndSettle();
      expect(docRepo.created.length, 1);
      expect(docRepo.created.first['title'], 'API RFC');
      expect(docRepo.created.first['content'], '# API Design');
    });
  });
}
