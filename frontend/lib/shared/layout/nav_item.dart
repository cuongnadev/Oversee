import 'package:flutter/material.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';

/// Sidebar & navigation rail destination descriptor aligned with Figma `Sidebar` (`1:6`).
class NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final FigmaIconType figmaIcon;
  final String? shortcut;
  final String? badgeText;
  final bool isAccentBadge;

  const NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.figmaIcon,
    this.shortcut,
    this.badgeText,
    this.isAccentBadge = false,
  });

  // 1. WORKSPACE group (Figma 1:50)
  static const List<NavItem> workspaceGroupItems = [
    NavItem(
      keyName: 'inbox',
      label: 'Inbox',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      figmaIcon: FigmaIconType.inbox,
    ),
    NavItem(
      keyName: 'my_tasks',
      label: 'My Tasks',
      icon: Icons.checklist_rounded,
      selectedIcon: Icons.checklist_rounded,
      figmaIcon: FigmaIconType.listChecks,
      shortcut: 'G M',
    ),
    NavItem(
      keyName: 'overview',
      label: 'Overview',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      figmaIcon: FigmaIconType.layoutDashboard,
      shortcut: 'G D',
    ),
  ];

  // 2. PLANNING group (Figma 1:95)
  static const List<NavItem> planningGroupItems = [
    NavItem(
      keyName: 'board',
      label: 'Board',
      icon: Icons.view_kanban_outlined,
      selectedIcon: Icons.view_kanban_rounded,
      figmaIcon: FigmaIconType.folderKanban,
      shortcut: 'G B',
    ),
    NavItem(
      keyName: 'backlog',
      label: 'Backlog',
      icon: Icons.layers_outlined,
      selectedIcon: Icons.layers_rounded,
      figmaIcon: FigmaIconType.layers3,
      shortcut: 'G L',
    ),
    NavItem(
      keyName: 'issues',
      label: 'Issues',
      icon: Icons.table_rows_outlined,
      selectedIcon: Icons.table_rows_rounded,
      figmaIcon: FigmaIconType.listChecks,
      shortcut: 'G I',
    ),
    NavItem(
      keyName: 'sprints',
      label: 'Sprints',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
      figmaIcon: FigmaIconType.timer,
      shortcut: 'G S',
    ),
    NavItem(
      keyName: 'roadmap',
      label: 'Roadmap',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag_rounded,
      figmaIcon: FigmaIconType.flag,
      shortcut: 'G R',
    ),
    NavItem(
      keyName: 'timeline',
      label: 'Timeline',
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline_rounded,
      figmaIcon: FigmaIconType.gitBranch,
      shortcut: 'G T',
    ),
    NavItem(
      keyName: 'calendar',
      label: 'Calendar',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      figmaIcon: FigmaIconType.calendar,
      shortcut: 'G C',
    ),
    NavItem(
      keyName: 'initiatives',
      label: 'Initiatives & Epics',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      figmaIcon: FigmaIconType.workflow,
    ),
  ];

  // 3. KNOWLEDGE group (Figma 1:180)
  static const List<NavItem> knowledgeGroupItems = [
    NavItem(
      keyName: 'documents',
      label: 'Documents',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
      figmaIcon: FigmaIconType.fileText,
    ),
    NavItem(
      keyName: 'reports',
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      figmaIcon: FigmaIconType.barChart,
    ),
  ];

  // 4. AI TEAM group (Figma 1:206)
  static const List<NavItem> aiTeamGroupItems = [
    NavItem(
      keyName: 'ai_assistant',
      label: 'AI Assistant',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      figmaIcon: FigmaIconType.sparkles,
      badgeText: 'BETA',
      isAccentBadge: true,
    ),
    NavItem(
      keyName: 'auto_schedule',
      label: 'Auto Schedule',
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule_rounded,
      figmaIcon: FigmaIconType.timer,
    ),
  ];

  // 5. CONFIGURATION group (Figma 1:231)
  static const List<NavItem> configurationGroupItems = [
    NavItem(
      keyName: 'members',
      label: 'Members',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      figmaIcon: FigmaIconType.users,
    ),
    NavItem(
      keyName: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      figmaIcon: FigmaIconType.bell,
    ),
    NavItem(
      keyName: 'integrations',
      label: 'Integrations',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
      figmaIcon: FigmaIconType.gitBranch,
    ),
    NavItem(
      keyName: 'settings',
      label: 'Project Settings',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      figmaIcon: FigmaIconType.settings2,
    ),
  ];

  // Bottom utility routes (Figma 1:273)
  static const List<NavItem> utilityRouteItems = [
    NavItem(
      keyName: 'api_docs',
      label: 'API docs',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      figmaIcon: FigmaIconType.bookOpen,
    ),
    NavItem(
      keyName: 'developer',
      label: 'Developer / MCP',
      icon: Icons.terminal_outlined,
      selectedIcon: Icons.terminal_rounded,
      figmaIcon: FigmaIconType.terminal,
      badgeText: 'DEV',
    ),
  ];

  /// Ordered navigation groups matching Figma sidebar structure.
  static const List<(String, List<NavItem>)> navGroups = [
    ('WORKSPACE', workspaceGroupItems),
    ('PLANNING', planningGroupItems),
    ('KNOWLEDGE', knowledgeGroupItems),
    ('AI TEAM', aiTeamGroupItems),
    ('CONFIGURATION', configurationGroupItems),
  ];

  /// Flat list of all grouped sidebar navigation items.
  static final List<NavItem> projectNavItems = [
    ...workspaceGroupItems,
    ...planningGroupItems,
    ...knowledgeGroupItems,
    ...aiTeamGroupItems,
    ...configurationGroupItems,
  ];

  /// Resolves the GoRouter destination path for any sidebar item key.
  static String routeFor(String keyName, String workspaceId, String projectId) {
    switch (keyName) {
      case 'inbox':
        return AppRoutes.projectInboxPath(workspaceId, projectId);
      case 'my_tasks':
        return AppRoutes.projectMyTasksPath(workspaceId, projectId);
      case 'overview':
        return AppRoutes.projectOverviewPath(workspaceId, projectId);
      case 'dashboard':
        return AppRoutes.projectDashboardPath(workspaceId, projectId);
      case 'board':
        return AppRoutes.projectBoardPath(workspaceId, projectId);
      case 'backlog':
        return AppRoutes.projectBacklogPath(workspaceId, projectId);
      case 'issues':
        return AppRoutes.projectIssuesPath(workspaceId, projectId);
      case 'sprints':
        return AppRoutes.projectSprintsPath(workspaceId, projectId);
      case 'planning':
        return AppRoutes.projectSprintPlanningPath(workspaceId, projectId);
      case 'roadmap':
        return AppRoutes.projectRoadmapPath(workspaceId, projectId);
      case 'timeline':
        return AppRoutes.projectTimelinePath(workspaceId, projectId);
      case 'calendar':
        return AppRoutes.projectCalendarPath(workspaceId, projectId);
      case 'initiatives':
        return AppRoutes.projectInitiativesPath(workspaceId, projectId);
      case 'documents':
        return AppRoutes.projectDocumentsPath(workspaceId, projectId);
      case 'reports':
        return AppRoutes.projectReportsPath(workspaceId, projectId);
      case 'ai_assistant':
        return AppRoutes.projectAiAssistantPath(workspaceId, projectId);
      case 'auto_schedule':
        return AppRoutes.projectAutoSchedulePath(workspaceId, projectId);
      case 'members':
        return AppRoutes.projectMembersPath(workspaceId, projectId);
      case 'notifications':
        return AppRoutes.projectNotificationsPath(workspaceId, projectId);
      case 'integrations':
        return AppRoutes.projectIntegrationsPath(workspaceId, projectId);
      case 'settings':
        return AppRoutes.projectSettingsPath(workspaceId, projectId);
      case 'api_docs':
        return AppRoutes.projectApiDocsPath(workspaceId, projectId);
      case 'developer':
        return AppRoutes.projectDeveloperPath(workspaceId, projectId);
      default:
        return AppRoutes.projectOverviewPath(workspaceId, projectId);
    }
  }
}
