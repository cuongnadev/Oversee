import 'package:flutter/material.dart';

class NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  static const List<NavItem> projectNavItems = [
    NavItem(
      keyName: 'overview',
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    NavItem(
      keyName: 'backlog',
      label: 'Backlog',
      icon: Icons.format_list_bulleted_rounded,
      selectedIcon: Icons.format_list_bulleted_rounded,
    ),
    NavItem(
      keyName: 'board',
      label: 'Board',
      icon: Icons.view_kanban_outlined,
      selectedIcon: Icons.view_kanban_rounded,
    ),
    NavItem(
      keyName: 'sprints',
      label: 'Sprints',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
    ),
    NavItem(
      keyName: 'dashboard',
      label: 'Dashboard',
      icon: Icons.bar_chart_rounded,
      selectedIcon: Icons.bar_chart_rounded,
    ),
    NavItem(
      keyName: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];
}
