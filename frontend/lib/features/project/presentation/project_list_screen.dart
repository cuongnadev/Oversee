import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace Projects Management Screen aligned with Figma design system.
/// Displays searchable Grid/List project views, quick navigation shortcuts,
/// pagination, and project creation dialog.
class ProjectListScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const ProjectListScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final _searchController = TextEditingController();
  bool _isListView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final projectState = ref.watch(projectListNotifierProvider(widget.workspaceId));
    final notifier = ref.read(projectListNotifierProvider(widget.workspaceId).notifier);
    final authState = ref.watch(authNotifierProvider);

    final displayProjects = projectState.filteredProjects;
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
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          height: 60.0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.0),
            ),
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
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 28.0,
            vertical: 28.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Figma .page-heading
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
                      onPressed: () =>
                          CreateProjectDialog.show(context, workspaceId: widget.workspaceId),
                    ),
                  ],
                ),
                const SizedBox(height: 22.0),

                // Figma-styled Filter & Layout Switch Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420.0),
                          child: AppTextFormField(
                            controller: _searchController,
                            hintText: 'Search projects by name or key...',
                            prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: textMuted),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded, size: 15.0, color: textMuted),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
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
                      ),
                      const SizedBox(width: 12.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: AppColors.surface2For(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '${projectState.total} total',
                          style: AppTypography.mono(isDark, fontSize: 11.0, color: textSecondary),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 10.0),
                        // Figma .layout-switch
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
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                // Error Message
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
                    child: projectState.searchQuery.isNotEmpty
                        ? AppEmptyState.noSearchResults(
                            query: projectState.searchQuery,
                            onClearFilters: () {
                              setState(() {
                                _searchController.clear();
                              });
                              notifier.setSearchQuery('');
                            },
                          )
                        : AppEmptyState.noProjects(
                            onCreateProject: () => CreateProjectDialog.show(
                              context,
                              workspaceId: widget.workspaceId,
                            ),
                          ),
                  ),
                ] else ...[
                  if (isMobile) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayProjects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        return _buildProjectCard(context, displayProjects[index]);
                      },
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
                        itemBuilder: (context, index) {
                          return _buildProjectListRow(context, displayProjects[index]);
                        },
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
                        mainAxisExtent: 200.0,
                      ),
                      itemCount: displayProjects.length,
                      itemBuilder: (context, index) {
                        return _buildProjectCard(context, displayProjects[index]);
                      },
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
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final initial = project.name.trim().isNotEmpty
        ? project.name.trim()[0].toUpperCase()
        : (project.key.isNotEmpty ? project.key[0].toUpperCase() : 'P');

    return AppCard(
      padding: const EdgeInsets.all(18.0),
      onTap: () => _navigateProjectAction(context, project, 'overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Figma .project-icon square monogram
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              // Monospace Project Key badge
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
              const Spacer(),
              _buildProjectMenu(context, project, textMuted),
            ],
          ),
          const SizedBox(height: 12.0),

          // Project Name
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

          // Project Description
          Expanded(
            child: Text(
              project.description != null && project.description!.isNotEmpty
                  ? project.description!
                  : 'No description provided.',
              style: TextStyle(
                fontSize: 12.0,
                color: textSecondary,
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Divider(height: 18.0, color: borderSoft),

          // Footer metadata & quick action
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
              InkWell(
                onTap: () => _navigateProjectAction(context, project, 'board'),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  child: Text(
                    'Board',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
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
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

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
              width: 32.0,
              height: 32.0,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: accentColor.withValues(alpha: 0.22)),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 12.5),
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
