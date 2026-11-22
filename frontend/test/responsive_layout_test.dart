import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/shared/layout/layout.dart';

Widget _buildResponsiveApp({
  required double width,
  required double height,
  required Widget child,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('ResponsiveAppShell Layout Adaptation Tests', () {
    testWidgets('Renders Mobile layout with bottom navigation and drawer on width < 600',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildResponsiveApp(
          width: 400,
          height: 800,
          child: const ResponsiveAppShell(
            workspaceId: 'ws-mobile',
            projectId: 'proj-mobile',
            currentRoute: 'overview',
            title: 'Project Overview',
            body: Center(child: Text('Mobile Body Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile elements
      expect(find.byType(MobileBottomNav), findsOneWidget);
      expect(find.byType(DesktopSidebar), findsNothing);
      expect(find.byType(TabletNavRail), findsNothing);
      expect(find.text('Mobile Body Content'), findsOneWidget);

      // Open drawer via hamburger icon
      final menuBtn = find.byTooltip('Navigation Menu');
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MobileAppDrawer), findsOneWidget);
    });

    testWidgets('Renders Tablet layout with NavigationRail on width 600 - 1024',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildResponsiveApp(
          width: 800,
          height: 1000,
          child: const ResponsiveAppShell(
            workspaceId: 'ws-tablet',
            projectId: 'proj-tablet',
            currentRoute: 'board',
            title: 'Kanban Board',
            body: Center(child: Text('Tablet Board Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TabletNavRail), findsOneWidget);
      expect(find.byType(DesktopSidebar), findsNothing);
      expect(find.byType(MobileBottomNav), findsNothing);
      expect(find.text('Tablet Board Content'), findsOneWidget);
    });

    testWidgets('Renders Desktop layout with full collapsible Sidebar on width > 1024',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildResponsiveApp(
          width: 1280,
          height: 800,
          child: const ResponsiveAppShell(
            workspaceId: 'ws-desktop',
            projectId: 'proj-desktop',
            currentRoute: 'backlog',
            title: 'Product Backlog',
            body: Center(child: Text('Desktop Backlog Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopSidebar), findsOneWidget);
      expect(find.byType(TabletNavRail), findsNothing);
      expect(find.byType(MobileBottomNav), findsNothing);
      expect(find.text('Desktop Backlog Content'), findsOneWidget);

      // Sidebar collapse toggle
      final collapseBtn = find.byTooltip('Collapse Sidebar');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Now sidebar is collapsed, tooltip changes to 'Expand Sidebar'
      final expandBtn = find.byTooltip('Expand Sidebar');
      expect(expandBtn, findsOneWidget);

      // Tap again to re-expand
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Collapse Sidebar'), findsOneWidget);

      // Figma sidebar elements: project selector, quick search, 5 collapsible nav groups & utility actions
      expect(find.text('Search anything'), findsOneWidget);
      expect(find.text('WORKSPACE'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('My Tasks'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('PLANNING'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Roadmap'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Initiatives & Epics'), findsOneWidget);
      expect(find.text('API docs'), findsOneWidget);
      expect(find.text('Developer / MCP'), findsOneWidget);
      expect(find.text('DEV'), findsOneWidget);

      // Collapse PLANNING group hides its items and brings lower Figma groups into view
      await tester.tap(find.text('PLANNING'));
      await tester.pumpAndSettle();
      expect(find.text('Board'), findsNothing);
      expect(find.text('KNOWLEDGE'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('AI TEAM'), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('BETA'), findsOneWidget);
      expect(find.text('CONFIGURATION'), findsOneWidget);

      // Re-expand PLANNING group restores its items
      await tester.tap(find.text('PLANNING'));
      await tester.pumpAndSettle();
      expect(find.text('Board'), findsOneWidget);
    });
  });

  group('AppHeader & Breadcrumbs Tests', () {
    testWidgets('AppHeader displays breadcrumbs hierarchy and user menu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildResponsiveApp(
          width: 1200,
          height: 800,
          child: const Scaffold(
            appBar: AppHeader(
              workspaceId: 'my-org',
              projectId: 'core-api',
              currentViewTitle: 'Sprints',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace: my-org'), findsOneWidget);
      expect(find.text('core-api'), findsOneWidget);
      expect(find.text('Sprints'), findsOneWidget);

      // User profile popup menu
      final profileBtn = find.byTooltip('User Profile');
      expect(profileBtn, findsOneWidget);
      await tester.tap(profileBtn);
      await tester.pumpAndSettle();

      expect(find.text('All Workspaces'), findsOneWidget);
      expect(find.text('Workspace Settings'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}
