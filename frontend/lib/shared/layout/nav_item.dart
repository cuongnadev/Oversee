import 'package:flutter/material.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';

/// Sidebar & navigation rail destination descriptor aligned with Figma `Layout.tsx` `NAV_GROUPS`.
class NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final FigmaIconType figmaIcon;
  final String? shortcut;

  const NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.figmaIcon,
    this.shortcut,
  });

  static const List<NavItem> projectNavItems = [
    NavItem(
      keyName: 'overview',
      label: 'Overview',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      figmaIcon: FigmaIconType.inbox,
      shortcut: 'G O',
    ),
    NavItem(
      keyName: 'dashboard',
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      figmaIcon: FigmaIconType.layoutDashboard,
      shortcut: 'G D',
    ),
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
      keyName: 'sprints',
      label: 'Sprints',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
      figmaIcon: FigmaIconType.timer,
      shortcut: 'G S',
    ),
    NavItem(
      keyName: 'planning',
      label: 'Planning',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      figmaIcon: FigmaIconType.workflow,
      shortcut: 'G P',
    ),
    NavItem(
      keyName: 'team',
      label: 'Members',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      figmaIcon: FigmaIconType.users,
    ),
    NavItem(
      keyName: 'settings',
      label: 'Settings',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      figmaIcon: FigmaIconType.settings2,
    ),
  ];
}
