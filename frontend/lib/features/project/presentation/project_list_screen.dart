import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

enum _ProjectStatusFilter { all, active, archived }

enum _ProjectSort { nameAsc, keyAsc, mostMembers, newest }

/// Workspace Projects Management Hub aligned with Figma design system.
/// Displays workspace context banner, KPI metrics, search/filter/sort toolbar,
/// Grid/List project views, quick navigation shortcuts, and dedicated project creation.
class ProjectListScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const ProjectListScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final _searchController = TextEditingController();
  bool _isListView = false;
  _ProjectStatusFilter _statusFilter = _ProjectStatusFilter.all;
  _ProjectSort _sort = _ProjectSort.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateProject(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.workspaceProjectCreatePath(widget.workspaceId));
    } else {
      CreateProjectDialog.show(context, workspaceId: widget.workspaceId);
    }
  }

  void _navigateProjectAction(BuildContext context, ProjectModel project, String routeKey) {
    switch (routeKey) {
      case 'overview':
        context.go(AppRoutes.projectOverviewPath(widget.workspaceId, project.id));
        break;
      case 'backlog':
        context.go(AppRoutes.projectBacklogPath(widget.workspaceId, project.id));
        break;
      case 'board':
        context.go(AppRoutes.projectBoardPath(widget.workspaceId, project.id));
        break;
      case 'sprints':
        context.go(AppRoutes.projectSprintsPath(widget.workspaceId, project.id));
        break;
      case 'settings':
        context.go(AppRoutes.projectSettingsPath(widget.workspaceId, project.id));
        break;
    }
  }

  List<ProjectModel> _applyStatusAndSort(List<ProjectModel> projects) {
    final filtered = projects.where((p) {
      switch (_statusFilter) {
        case _ProjectStatusFilter.all:
          return true;
        case _ProjectStatusFilter.active:
          return !p.isArchived;
        case _ProjectStatusFilter.archived:
          return p.isArchived;
      }
    }).toList();

    switch (_sort) {
      case _ProjectSort.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _ProjectSort.keyAsc:
        filtered.sort((a, b) => a.key.compareTo(b.key));
        break;
      case _ProjectSort.mostMembers:
        filtered.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
      case _ProjectSort.newest:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
    }
    return filtered;
  }

  Color _monogramColorFor(String key) {
    final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return AppColors.avatarPalette[hash % AppColors.avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final projectState = ref.watch(projectListNotifierProvider(widget.workspaceId));
    final notifier = ref.read(projectListNotifierProvider(widget.workspaceId).notifier);
    final authState = ref.watch(authNotifierProvider);
    final workspaceState = ref.watch(workspaceNotifierProvider);

    final WorkspaceModel? activeWorkspace = workspaceState.workspaces
            .where((w) => w.id == widget.workspaceId)
            .firstOrNull ??
        workspaceState.selectedWorkspace;

    final displayProjects = _applyStatusAndSort(projectState.filteredProjects);
    final activeCount = projectState.projects.where((p) => !p.isArchived).length;
    final totalMembers =
        projectState.projects.fold<int>(0, (sum, project) => sum + project.memberCount);

    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    final userDisplayName = (authState.user?.fullName.isNotEmpty ?? false)
        ? authState.user!.fullName
        : (authState.email?.split('@').first ?? 'User');

    return Scaffold(
      backgroundColor: AppColors.bgFor(isDark),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64.0),
        child: Container(
          height: 64.0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Row(
            children: [
              WorkspaceSwitcherDropdown(
                activeWorkspaceId: widget.workspaceId,
                compact: isMobile,
              ),
              const SizedBox(width: 8.0),
              Icon(Icons.chevron_right_rounded, size: 15.0, color: textMuted),
              const SizedBox(width: 6.0),
              Flexible(
                child: Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5.0,
                        height: 5.0,
                        decoration: BoxDecoration(
                          color: AppColors.successFor(isDark),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5.0),
                      Text(
                        'workspace',
                        style: AppTypography.mono(isDark, fontSize: 9.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Refresh Projects',
                icon: Icon(Icons.refresh_rounded, size: 18.0, color: textSecondary),
                onPressed: () => notifier.loadProjects(page: projectState.page),
              ),
              IconButton(
                tooltip: 'Workspace Settings',
                icon: Icon(Icons.tune_rounded, size: 18.0, color: textSecondary),
                onPressed: () => context.go(AppRoutes.workspaceSettingsPath(widget.workspaceId)),
              ),
              IconButton(
                tooltip: 'Toggle Theme',
                icon: Icon(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 18.0,
                  color: textSecondary,
                ),
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 4.0),
                UserAvatar(
                  name: userDisplayName,
                  size: UserAvatarSize.xs,
                  showStatus: true,
                  isOnline: true,
                ),
              ],
              const SizedBox(width: 4.0),
              IconButton(
                tooltip: 'Logout',
                icon: Icon(Icons.logout_rounded, size: 18.0, color: textSecondary),
                onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadProjects(page: projectState.page),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 28.0,
            vertical: 26.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Workspace Hero Context Banner (Figma .sprint-banner style)
                  if (activeWorkspace != null) ...[
                    _buildWorkspaceBanner(context, activeWorkspace, isDark, isMobile),
                    const SizedBox(height: 18.0),
                  ],

                  // Page Heading
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16.0,
                    runSpacing: 12.0,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WORKSPACE PROJECTS', style: AppTypography.eyebrow(isDark)),
                          const SizedBox(height: 6.0),
                          Text(
                            'Projects',
                            style: TextStyle(
                              fontSize: 25.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.8,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5.0),
                          Text(
                            'Track issues, backlogs, sprints, and roadmaps for this workspace.',
                            style: TextStyle(fontSize: 12.5, color: textSecondary),
                          ),
                        ],
                      ),
                      AppPrimaryButton(
                        icon: Icons.add_rounded,
                        label: 'New Project',
                        onPressed: () => _openCreateProject(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18.0),

                  // 4-Card KPI Summary Strip
                  if (!projectState.isLoading && projectState.projects.isNotEmpty) ...[
                    _buildMetricsRow(
                      isDark: isDark,
                      total: projectState.total,
                      activeCount: activeCount,
                      totalMembers: totalMembers,
                      workspaceRole: activeWorkspace?.userRole.label ?? 'Member',
                    ),
                    const SizedBox(height: 18.0),
                  ],

                  // Filter, Status Chips, Sort & Layout Switch Toolbar
                  _buildToolbar(
                    isDark: isDark,
                    isMobile: isMobile,
                    total: projectState.total,
                    notifier: notifier,
                  ),
                  const SizedBox(height: 20.0),

                  // Error Banner
                  if (projectState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      margin: const EdgeInsets.only(bottom: 18.0),
                      decoration: BoxDecoration(
                        color: dangerSoft,
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: errorColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: errorColor, size: 19.0),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              projectState.errorMessage!,
                              style: TextStyle(color: errorColor, fontSize: 12.5),
                            ),
                          ),
                          AppOutlinedButton(
                            label: 'Retry',
                            onPressed: () => notifier.loadProjects(page: projectState.page),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Content
                  if (projectState.isLoading) ...[
                    const ProjectGridSkeleton(),
                  ] else if (displayProjects.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: borderColor),
                      ),
                      child: projectState.searchQuery.isNotEmpty ||
                              _statusFilter != _ProjectStatusFilter.all
                          ? AppEmptyState.noSearchResults(
                              query: projectState.searchQuery,
                              onClearFilters: () {
                                setState(() {
                                  _searchController.clear();
                                  _statusFilter = _ProjectStatusFilter.all;
                                });
                                notifier.setSearchQuery('');
                              },
                            )
                          : AppEmptyState.noProjects(
                              onCreateProject: () => _openCreateProject(context),
                            ),
                    ),
                  ] else ...[
                    if (isMobile) ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayProjects.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                        itemBuilder: (context, index) =>
                            _buildProjectCard(context, displayProjects[index]),
                      ),
                    ] else if (_isListView) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFor(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusLg),
                          border: Border.all(color: borderColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayProjects.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1.0, color: AppColors.borderSoftFor(isDark)),
                          itemBuilder: (context, index) =>
                              _buildProjectListRow(context, displayProjects[index]),
                        ),
                      ),
                    ] else ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420.0,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          mainAxisExtent: 214.0,
                        ),
                        itemCount: displayProjects.length,
                        itemBuilder: (context, index) =>
                            _buildProjectCard(context, displayProjects[index]),
                      ),
                    ],

                    // Pagination controls
                    if (projectState.totalPages > 1) ...[
                      const SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Previous Page',
                            onPressed: projectState.page > 1
                                ? () => notifier.loadProjects(page: projectState.page - 1)
                                : null,
                          ),
                          const SizedBox(width: 12.0),
                          Text(
                            'Page ${projectState.page} of ${projectState.totalPages}',
                            style: AppTypography.mono(isDark, fontSize: 11.5, color: textSecondary),
                          ),
                          const SizedBox(width: 12.0),
                          AppIconButton(
                            icon: Icons.chevron_right_rounded,
                            tooltip: 'Next Page',
                            onPressed: projectState.page < projectState.totalPages
                                ? () => notifier.loadProjects(page: projectState.page + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceBanner(
    BuildContext context,
    WorkspaceModel ws,
    bool isDark,
    bool isMobile,
  ) {
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14.0 : 18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentSoft.withValues(alpha: isDark ? 0.65 : 0.55),
            AppColors.surfaceFor(isDark),
          ],
          stops: const [0.0, 0.72],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: Color.lerp(borderColor, accentColor, 0.22) ?? borderColor),
      ),
      child: Wrap(
        spacing: 14.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(
                  CreateWorkspaceDialog.computeInitials(ws.name),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 240.0 : 480.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ws.name,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        RoleBadge(role: ws.userRole, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      ws.description?.isNotEmpty == true ? ws.description! : '@${ws.slug}',
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              AppOutlinedButton(
                height: 32.0,
                icon: Icons.hub_outlined,
                label: 'All Workspaces',
                onPressed: () => context.go(AppRoutes.workspaces),
              ),
              AppOutlinedButton(
                height: 32.0,
                icon: Icons.tune_rounded,
                label: 'Settings',
                textColor: textMuted,
                onPressed: () => context.go(AppRoutes.workspaceSettingsPath(widget.workspaceId)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow({
    required bool isDark,
    required int total,
    required int activeCount,
    required int totalMembers,
    required String workspaceRole,
  }) {
    final accentColor = AppColors.accentFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final infoColor = AppColors.infoFor(isDark);
    final warningColor = AppColors.warningFor(isDark);

    final cards = [
      _ProjectStatTile(
        label: 'Total Projects',
        value: '$total',
        caption: 'In this workspace',
        dotColor: accentColor,
        isDark: isDark,
      ),
      _ProjectStatTile(
        label: 'Active Projects',
        value: '$activeCount',
        caption: 'Ready for sprint work',
        dotColor: successColor,
        isDark: isDark,
      ),
      _ProjectStatTile(
        label: 'Project Seats',
        value: '$totalMembers',
        caption: 'Combined project members',
        dotColor: infoColor,
        isDark: isDark,
      ),
      _ProjectStatTile(
        label: 'Your Access',
        value: workspaceRole,
        caption: 'Workspace permission level',
        dotColor: warningColor,
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760.0) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 12.0),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 12.0) / 2, child: card),
          ],
        );
      },
    );
  }

  Widget _buildToolbar({
    required bool isDark,
    required bool isMobile,
    required int total,
    required ProjectListNotifier notifier,
  }) {
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 360.0,
                child: AppTextFormField(
                  controller: _searchController,
                  hintText: 'Search projects by name or key...',
                  prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 15.0, color: textMuted),
                          onPressed: () {
                            setState(() => _searchController.clear());
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  onChanged: (value) {
                    setState(() {});
                    notifier.setSearchQuery(value);
                  },
                ),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface2For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      '$total total',
                      style: AppTypography.mono(isDark, fontSize: 11.0, color: textSecondary),
                    ),
                  ),
                  Container(
                    height: 32.0,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface2For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_ProjectSort>(
                        value: _sort,
                        isDense: true,
                        dropdownColor: AppColors.surfaceFor(isDark),
                        icon: Icon(Icons.unfold_more_rounded, size: 14.0, color: textMuted),
                        style: TextStyle(fontSize: 11.5, color: textPrimary),
                        items: const [
                          DropdownMenuItem(value: _ProjectSort.nameAsc, child: Text('Sort: Name A–Z')),
                          DropdownMenuItem(value: _ProjectSort.keyAsc, child: Text('Sort: Key')),
                          DropdownMenuItem(
                              value: _ProjectSort.mostMembers, child: Text('Sort: Most Members')),
                          DropdownMenuItem(value: _ProjectSort.newest, child: Text('Sort: Newest')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sort = val);
                        },
                      ),
                    ),
                  ),
                  if (!isMobile)
                    Container(
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        color: AppColors.bgFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LayoutSwitchButton(
                            tooltip: 'Grid view',
                            icon: Icons.grid_view_rounded,
                            isActive: !_isListView,
                            isDark: isDark,
                            onTap: () => setState(() => _isListView = false),
                          ),
                          const SizedBox(width: 2.0),
                          _LayoutSwitchButton(
                            tooltip: 'List view',
                            icon: Icons.view_list_rounded,
                            isActive: _isListView,
                            isDark: isDark,
                            onTap: () => setState(() => _isListView = true),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: [
              for (final (filter, label) in [
                (_ProjectStatusFilter.all, 'All'),
                (_ProjectStatusFilter.active, 'Active'),
                (_ProjectStatusFilter.archived, 'Archived'),
              ])
                InkWell(
                  onTap: () => setState(() => _statusFilter = filter),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: _statusFilter == filter ? accentSoft : AppColors.surface2For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: _statusFilter == filter
                            ? accentColor.withValues(alpha: 0.35)
                            : borderColor,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: _statusFilter == filter ? FontWeight.w600 : FontWeight.w500,
                        color: _statusFilter == filter ? accentColor : textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final monogramColor = _monogramColorFor(project.key.isNotEmpty ? project.key : project.name);

    final initial = project.name.trim().isNotEmpty
        ? project.name.trim()[0].toUpperCase()
        : (project.key.isNotEmpty ? project.key[0].toUpperCase() : 'P');
    final createdLabel = project.createdAt != null
        ? DateFormat('MMM d, y').format(project.createdAt!.toLocal())
        : null;

    return AppCard(
      padding: const EdgeInsets.all(18.0),
      onTap: () => _navigateProjectAction(context, project, 'overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: monogramColor.withValues(alpha: isDark ? 0.25 : 0.14),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: monogramColor.withValues(alpha: 0.32)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: monogramColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: AppColors.surface2For(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  project.key,
                  style: AppTypography.mono(
                    isDark,
                    fontSize: 11.0,
                    color: accentColor,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: project.isArchived
                      ? AppColors.warningSoftFor(isDark)
                      : AppColors.greenSoftFor(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  project.isArchived ? 'ARCHIVED' : 'ACTIVE',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: project.isArchived
                        ? AppColors.warningFor(isDark)
                        : AppColors.successFor(isDark),
                  ),
                ),
              ),
              const Spacer(),
              _buildProjectMenu(context, project, textMuted),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            project.name,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4.0),
          Expanded(
            child: Text(
              project.description != null && project.description!.isNotEmpty
                  ? project.description!
                  : 'No description provided.',
              style: TextStyle(fontSize: 12.0, color: textSecondary, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createdLabel != null) ...[
            Text(
              'Created $createdLabel',
              style: TextStyle(fontSize: 10.5, color: textMuted),
            ),
          ],
          Divider(height: 16.0, color: borderSoft),
          Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 14.5, color: textMuted),
              const SizedBox(width: 5.0),
              Expanded(
                child: Text(
                  '${project.memberCount} members',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _QuickRouteLink(
                label: 'Board',
                color: textSecondary,
                onTap: () => _navigateProjectAction(context, project, 'board'),
              ),
              const SizedBox(width: 4.0),
              _QuickRouteLink(
                label: 'Backlog',
                color: textSecondary,
                onTap: () => _navigateProjectAction(context, project, 'backlog'),
              ),
              const SizedBox(width: 6.0),
              InkWell(
                onTap: () => _navigateProjectAction(context, project, 'overview'),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 3.0),
                      Icon(Icons.arrow_forward_rounded, size: 13.5, color: accentColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectListRow(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final monogramColor = _monogramColorFor(project.key.isNotEmpty ? project.key : project.name);

    final initial = project.name.trim().isNotEmpty
        ? project.name.trim()[0].toUpperCase()
        : (project.key.isNotEmpty ? project.key[0].toUpperCase() : 'P');

    return InkWell(
      onTap: () => _navigateProjectAction(context, project, 'overview'),
      hoverColor: AppColors.hoverFor(isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: monogramColor.withValues(alpha: isDark ? 0.25 : 0.14),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: monogramColor.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: monogramColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.0,
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.surface2For(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                project.key,
                style: AppTypography.mono(isDark, fontSize: 10.5, color: accentColor)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (project.description != null && project.description!.isNotEmpty)
                    Text(
                      project.description!,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded, size: 14.0, color: textMuted),
                const SizedBox(width: 4.0),
                Text(
                  '${project.memberCount} members',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
            const SizedBox(width: 12.0),
            AppOutlinedButton(
              height: 30.0,
              label: 'Board',
              onPressed: () => _navigateProjectAction(context, project, 'board'),
            ),
            const SizedBox(width: 6.0),
            AppOutlinedButton(
              height: 30.0,
              label: 'Backlog',
              onPressed: () => _navigateProjectAction(context, project, 'backlog'),
            ),
            const SizedBox(width: 6.0),
            _buildProjectMenu(context, project, textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectMenu(BuildContext context, ProjectModel project, Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, size: 18.0, color: iconColor),
      tooltip: 'Project Options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onSelected: (routeKey) => _navigateProjectAction(context, project, routeKey),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'overview', child: Text('Overview')),
        PopupMenuItem(value: 'backlog', child: Text('Backlog')),
        PopupMenuItem(value: 'board', child: Text('Kanban Board')),
        PopupMenuItem(value: 'sprints', child: Text('Sprints')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'settings', child: Text('Project Settings')),
      ],
    );
  }
}

class _ProjectStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color dotColor;
  final bool isDark;

  const _ProjectStatTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.dotColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryFor(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 21.0,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: AppColors.textPrimaryFor(isDark),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4.0),
          Text(
            caption,
            style: TextStyle(fontSize: 10.5, color: AppColors.textMutedFor(isDark)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickRouteLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickRouteLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }
}

class _LayoutSwitchButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _LayoutSwitchButton({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Container(
          width: 28.0,
          height: 26.0,
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface3For(isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 15.0,
            color: isActive ? AppColors.textPrimaryFor(isDark) : AppColors.textMutedFor(isDark),
          ),
        ),
      ),
    );
  }
}
