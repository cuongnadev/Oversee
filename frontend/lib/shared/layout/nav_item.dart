import 'package:flutter/material.dart';

/// Sidebar & navigation rail destination descriptor aligned with Figma NAV_GROUPS.
class NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? shortcut;

  const NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.shortcut,
  });

  static const List<NavItem> projectNavItems = [
    NavItem(
      keyName: 'overview',
      label: 'Overview',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      shortcut: 'G O',
    ),
    NavItem(
      keyName: 'dashboard',
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      shortcut: 'G D',
    ),
    NavItem(
      keyName: 'board',
      label: 'Board',
      icon: Icons.view_kanban_outlined,
      selectedIcon: Icons.view_kanban_rounded,
      shortcut: 'G B',
    ),
    NavItem(
      keyName: 'backlog',
      label: 'Backlog',
      icon: Icons.layers_outlined,
      selectedIcon: Icons.layers_rounded,
      shortcut: 'G L',
    ),
    NavItem(
      keyName: 'sprints',
      label: 'Sprints',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
      shortcut: 'G S',
    ),
    NavItem(
      keyName: 'settings',
      label: 'Settings',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
    ),
  ];
}
