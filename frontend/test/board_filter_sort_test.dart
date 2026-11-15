import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testIssues = [
    const IssueModel(
      id: 'iss-1',
      projectId: 'proj-1',
      issueNumber: 101,
      title: 'Setup PostgreSQL Database',
      type: IssueType.task,
      status: IssueStatus.todo,
      priority: IssuePriority.high,
      estimate: 3.0,
      reporterId: 'u-1',
      assigneeId: 'user-alice',
      backlogRank: 10.0,
    ),
    const IssueModel(
      id: 'iss-2',
      projectId: 'proj-1',
      issueNumber: 102,
      title: 'OAuth Authentication Flow',
      type: IssueType.story,
      status: IssueStatus.inProgress,
      priority: IssuePriority.urgent,
      estimate: 8.0,
      reporterId: 'u-1',
      assigneeId: 'user-bob',
      backlogRank: 20.0,
    ),
    const IssueModel(
      id: 'iss-3',
      projectId: 'proj-1',
      issueNumber: 103,
      title: 'Fix CSRF Vulnerability',
      type: IssueType.bug,
      status: IssueStatus.inReview,
      priority: IssuePriority.urgent,
      estimate: 5.0,
      reporterId: 'u-1',
      assigneeId: null, // unassigned
      backlogRank: 30.0,
    ),
    const IssueModel(
      id: 'iss-4',
      projectId: 'proj-1',
      issueNumber: 104,
      title: 'Update Documentation',
      type: IssueType.task,
      status: IssueStatus.done,
      priority: IssuePriority.lowest,
      estimate: 1.0,
      reporterId: 'u-1',
      assigneeId: 'user-bob',
      backlogRank: 40.0,
    ),
  ];

  group('IssueFilterState Serialization & URL Sync Tests', () {
    test('serializes filter state to query parameters correctly', () {
      const filter = IssueFilterState(
        searchQuery: 'auth',
        selectedTypes: {IssueType.story, IssueType.bug},
        selectedPriorities: {IssuePriority.urgent},
        selectedAssigneeId: 'user-bob',
        sortField: IssueSortField.priority,
        sortAscending: false,
      );

      final params = filter.toQueryParams();
      expect(params['search'], 'auth');
      expect(params['type'], contains('story'));
      expect(params['type'], contains('bug'));
      expect(params['priority'], 'urgent');
      expect(params['assignee'], 'user-bob');
      expect(params['sort'], 'priority');
      expect(params['order'], 'desc');
    });

    test('deserializes URL query parameters accurately into IssueFilterState', () {
      final queryParams = {
        'search': 'PostgreSQL',
        'type': 'task,bug',
        'priority': 'high,urgent',
        'assignee': 'me',
        'sort': 'estimate',
        'order': 'desc',
      };

      final filter = IssueFilterState.fromQueryParams(queryParams);
      expect(filter.searchQuery, 'PostgreSQL');
      expect(filter.selectedTypes, {IssueType.task, IssueType.bug});
      expect(filter.selectedPriorities, {IssuePriority.high, IssuePriority.urgent});
      expect(filter.selectedAssigneeId, 'me');
      expect(filter.sortField, IssueSortField.estimate);
      expect(filter.sortAscending, isFalse);
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.activeFilterCount, 7);
    });
  });

  group('IssueFilterState Filtering & Sorting Logic Tests', () {
    test('filters issues by title and key', () {
      const filterTitle = IssueFilterState(searchQuery: 'database');
      final resultTitle = filterTitle.apply(testIssues, projectKey: 'OVS');
      expect(resultTitle.length, 1);
      expect(resultTitle.first.issueNumber, 101);

      const filterKey = IssueFilterState(searchQuery: 'OVS-103');
      final resultKey = filterKey.apply(testIssues, projectKey: 'OVS');
      expect(resultKey.length, 1);
      expect(resultKey.first.issueNumber, 103);
    });

    test('filters issues by multiple types and priorities', () {
      const filterTypes = IssueFilterState(
        selectedTypes: {IssueType.story, IssueType.bug},
      );
      final resultTypes = filterTypes.apply(testIssues);
      expect(resultTypes.length, 2);
      expect(resultTypes.map((i) => i.type), containsAll([IssueType.story, IssueType.bug]));

      const filterPriority = IssueFilterState(
        selectedPriorities: {IssuePriority.urgent},
      );
      final resultPriority = filterPriority.apply(testIssues);
      expect(resultPriority.length, 2);
      expect(resultPriority.every((i) => i.priority == IssuePriority.urgent), isTrue);
    });

    test('filters issues by assignee ("me" and "unassigned")', () {
      const filterMe = IssueFilterState(selectedAssigneeId: 'me');
      final resultMe = filterMe.apply(
        testIssues,
        currentUserId: 'user-bob',
      );
      expect(resultMe.length, 2);
      expect(resultMe.every((i) => i.assigneeId == 'user-bob'), isTrue);

      const filterUnassigned = IssueFilterState(selectedAssigneeId: 'unassigned');
      final resultUnassigned = filterUnassigned.apply(testIssues);
      expect(resultUnassigned.length, 1);
      expect(resultUnassigned.first.issueNumber, 103);
    });

    test('sorts issues by priority descending (Urgent first)', () {
      const filter = IssueFilterState(
        sortField: IssueSortField.priority,
        sortAscending: true, // Default priority sort comparator puts urgent first
      );
      final sorted = filter.apply(testIssues);
      expect(sorted.first.priority, IssuePriority.urgent);
      expect(sorted.last.priority, IssuePriority.lowest);
    });

    test('sorts issues by story points (estimate)', () {
      const filter = IssueFilterState(
        sortField: IssueSortField.estimate,
        sortAscending: true,
      );
      final sorted = filter.apply(testIssues);
      // Highest estimate (8.0) first
      expect(sorted.first.estimate, 8.0);
      expect(sorted.last.estimate, 1.0);
    });
  });

  group('BoardFilterToolbar Widget Tests', () {
    testWidgets('renders search box, My Issues chip, Sort dropdown, and Filters button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardFilterToolbar(
              filter: const IssueFilterState(),
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('My Issues'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('triggers debounced onFilterChanged when typing into search input',
        (tester) async {
      IssueFilterState? receivedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardFilterToolbar(
              filter: const IssueFilterState(),
              onFilterChanged: (newFilter) {
                receivedFilter = newFilter;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Authentication');
      // Before debounce 300ms
      expect(receivedFilter, isNull);

      // Advance clock by 350ms to trigger debounce
      await tester.pump(const Duration(milliseconds: 350));
      expect(receivedFilter, isNotNull);
      expect(receivedFilter?.searchQuery, 'Authentication');
    });

    testWidgets('toggles My Issues chip and fires onFilterChanged',
        (tester) async {
      IssueFilterState? receivedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardFilterToolbar(
              filter: const IssueFilterState(),
              onFilterChanged: (newFilter) {
                receivedFilter = newFilter;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('My Issues'));
      await tester.pump();

      expect(receivedFilter?.selectedAssigneeId, 'me');
    });

    testWidgets('expands filter panel showing Type and Priority filter chips',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardFilterToolbar(
              filter: const IssueFilterState(),
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap "Filters" button to expand
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Type:'), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Bug'), findsOneWidget);

      expect(find.text('Priority:'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('shows filter count badge and Clear button when active filters exist',
        (tester) async {
      IssueFilterState? clearedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardFilterToolbar(
              filter: const IssueFilterState(
                searchQuery: 'test',
                selectedTypes: {IssueType.bug},
              ), // count = 2
              onFilterChanged: (f) {
                clearedFilter = f;
              },
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget); // badge count
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(clearedFilter?.hasActiveFilters, isFalse);
    });
  });
}
