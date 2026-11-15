import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace Projects Listing Screen.
/// Displays card grid or list view with search, pagination, and project creation shortcut.
class ProjectListScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const ProjectListScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final projectState = ref.watch(projectListNotifierProvider(widget.workspaceId));
    final notifier = ref.read(projectListNotifierProvider(widget.workspaceId).notifier);

    final displayProjects = projectState.filteredProjects;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12.0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WorkspaceSwitcherDropdown(activeWorkspaceId: widget.workspaceId),
            const SizedBox(width: 8.0),
            Text(
              '/',
              style: TextStyle(
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(width: 8.0),
            const Text('Projects', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Workspace Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.workspaceSettingsPath(widget.workspaceId)),
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Projects', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4.0),
                          Text(
                            'Track issues, backlogs, sprints, and roadmaps for this workspace.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    AppPrimaryButton(
                      icon: Icons.add_rounded,
                      label: 'New Project',
                      onPressed: () => CreateProjectDialog.show(context, workspaceId: widget.workspaceId),
                    ),
                  ],
                ),
                const SizedBox(height: 20.0),

                // Search & Filter Toolbar
                Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400.0),
                        child: AppTextFormField(
                          controller: _searchController,
                          hintText: 'Search projects by name or key...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20.0),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16.0),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.setSearchQuery('');
                                  },
                                )
                              : null,
                          onChanged: notifier.setSearchQuery,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Text(
                      '${projectState.total} total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Error Message
                if (projectState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            projectState.errorMessage!,
                            style: const TextStyle(color: AppColors.error),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.0),
                    child: Center(child: AppLoadingIndicator()),
                  ),
                ] else if (displayProjects.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: projectState.searchQuery.isNotEmpty ? 'No Matching Projects' : 'No Projects Found',
                      description: projectState.searchQuery.isNotEmpty
                          ? 'No projects matched "${projectState.searchQuery}". Try a different keyword.'
                          : 'This workspace doesn\'t have any projects yet. Create your first project to start organizing tasks, backlogs, and sprints.',
                      action: AppPrimaryButton(
                        icon: Icons.add_rounded,
                        label: 'Create First Project',
                        onPressed: () => CreateProjectDialog.show(context, workspaceId: widget.workspaceId),
                      ),
                    ),
                  ),
                ] else ...[
                  // Responsive Grid / List
                  if (isMobile) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayProjects.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        return _buildProjectCard(context, displayProjects[index]);
                      },
                    ),
                  ] else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520.0,
                        mainAxisSpacing: 16.0,
                        crossAxisSpacing: 16.0,
                        mainAxisExtent: 180.0,
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
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: () {
        context.go(AppRoutes.projectOverviewPath(widget.workspaceId, project.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Project Key Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 14.0, color: AppColors.primary),
                    const SizedBox(width: 4.0),
                    Text(
                      project.key,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick shortcuts menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 18.0, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                tooltip: 'Project Options',
                onSelected: (routeKey) {
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
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'overview', child: Text('Overview')),
                  const PopupMenuItem(value: 'backlog', child: Text('Backlog')),
                  const PopupMenuItem(value: 'board', child: Text('Kanban Board')),
                  const PopupMenuItem(value: 'sprints', child: Text('Sprints')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'settings', child: Text('Project Settings')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Project Name
          Text(
            project.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Divider(height: 16.0),

          // Footer meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 15.0,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    '${project.memberCount} members',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  context.go(AppRoutes.projectOverviewPath(widget.workspaceId, project.id));
                },
                borderRadius: BorderRadius.circular(4.0),
                child: Row(
                  children: [
                    Text(
                      'Open',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    const Icon(Icons.arrow_forward_rounded, size: 14.0, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
