import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';
import 'package:frontend/shared/widgets/widgets.dart';

enum _WorkspaceSort { nameAsc, newest, role }

/// Workspace Management Hub aligned with Figma design tokens.
/// Features KPI stats, search, role filtering, sorting, grid/list layouts, and dedicated creation route.
class WorkspaceListScreen extends ConsumerStatefulWidget {
  const WorkspaceListScreen({super.key});

  @override
  ConsumerState<WorkspaceListScreen> createState() => _WorkspaceListScreenState();
}

class _WorkspaceListScreenState extends ConsumerState<WorkspaceListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  RoleType? _selectedRole;
  _WorkspaceSort _sort = _WorkspaceSort.nameAsc;
  bool _isListView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateWorkspace(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.workspaceCreate);
    } else {
      CreateWorkspaceDialog.show(context);
    }
  }

  List<WorkspaceModel> _filteredAndSorted(List<WorkspaceModel> all) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = all.where((ws) {
      if (_selectedRole != null && ws.userRole != _selectedRole) {
        return false;
      }
      if (q.isEmpty) return true;
      return ws.name.toLowerCase().contains(q) ||
          ws.slug.toLowerCase().contains(q) ||
          (ws.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    switch (_sort) {
      case _WorkspaceSort.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _WorkspaceSort.newest:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
      case _WorkspaceSort.role:
        filtered.sort((a, b) => a.userRole.index.compareTo(b.userRole.index));
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
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    final userDisplayName = (authState.user?.fullName.isNotEmpty ?? false)
        ? authState.user!.fullName
        : (authState.email?.split('@').first ?? 'User');

    final allWorkspaces = workspaceState.workspaces;
    final visibleWorkspaces = _filteredAndSorted(allWorkspaces);
    final ownedCount = allWorkspaces.where((w) => w.userRole == RoleType.owner).length;
    final adminCount = allWorkspaces.where((w) => w.userRole == RoleType.admin).length;
    final activeWorkspace = workspaceState.selectedWorkspace;

    return Scaffold(
      backgroundColor: AppColors.bgFor(isDark),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64.0),
        child: Container(
          height: 64.0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14.0 : 24.0),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Row(
            children: [
              FigmaSidebarIcon(
                FigmaIconType.layers3,
                size: 19.0,
                color: accentColor,
                strokeWidth: 1.75,
              ),
              const SizedBox(width: 9.0),
              RichText(
                text: TextSpan(
                  text: 'oversee',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.fontFallback,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.9,
                    color: textPrimary,
                  ),
                  children: [
                    TextSpan(text: '.', style: TextStyle(color: accentColor)),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Icon(Icons.chevron_right_rounded, size: 15.0, color: textMuted),
              const SizedBox(width: 6.0),
              Text(
                'Workspaces',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh Workspaces',
                icon: Icon(Icons.refresh_rounded, size: 18.0, color: textSecondary),
                onPressed: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
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
              const SizedBox(width: 4.0),
              UserAvatar(
                name: userDisplayName,
                size: UserAvatarSize.xs,
                showStatus: true,
                isOnline: true,
              ),
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
        onRefresh: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 28.0,
            vertical: 28.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Heading (Figma .page-heading)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16.0,
                    runSpacing: 12.0,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WORKSPACES', style: AppTypography.eyebrow(isDark)),
                          const SizedBox(height: 6.0),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Your Workspaces',
                                style: TextStyle(
                                  fontSize: 25.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.8,
                                  color: textPrimary,
                                ),
                              ),
                              if (!workspaceState.isLoading) ...[
                                const SizedBox(width: 10.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface3For(isDark),
                                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                  ),
                                  child: Text(
                                    '${allWorkspaces.length}',
                                    style: AppTypography.mono(
                                      isDark,
                                      fontSize: 11.0,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5.0),
                          Text(
                            'Manage organizations, configure team access, and jump straight into active projects.',
                            style: TextStyle(fontSize: 12.5, color: textSecondary),
                          ),
                        ],
                      ),
                      AppPrimaryButton(
                        onPressed: () => _openCreateWorkspace(context),
                        icon: Icons.add_rounded,
                        label: 'New Workspace',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // KPI Summary Strip (Figma 4-card overview stats)
                  if (!workspaceState.isLoading && allWorkspaces.isNotEmpty) ...[
                    _buildSummaryStrip(
                      context,
                      isDark: isDark,
                      total: allWorkspaces.length,
                      ownedCount: ownedCount,
                      collaboratorCount: allWorkspaces.length - ownedCount,
                      adminCount: adminCount,
                      activeWorkspace: activeWorkspace,
                    ),
                    const SizedBox(height: 18.0),
                  ],

                  // Filter, Role Chips & Layout Switch Toolbar
                  if (!workspaceState.isLoading && allWorkspaces.isNotEmpty) ...[
                    _buildToolbar(
                      isDark: isDark,
                      isMobile: isMobile,
                      visibleCount: visibleWorkspaces.length,
                      totalCount: allWorkspaces.length,
                    ),
                    const SizedBox(height: 18.0),
                  ],

                  // Error Banner
                  if (workspaceState.errorMessage != null) ...[
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
                              workspaceState.errorMessage!,
                              style: TextStyle(color: errorColor, fontSize: 12.5),
                            ),
                          ),
                          AppOutlinedButton(
                            label: 'Retry',
                            onPressed: () =>
                                ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Content
                  if (workspaceState.isLoading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(child: AppLoadingIndicator()),
                    ),
                  ] else if (allWorkspaces.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: borderColor),
                      ),
                      child: AppEmptyState(
                        icon: Icons.layers_outlined,
                        title: 'No Workspaces Found',
                        description:
                            'You are not a member of any workspace yet. Create your first workspace to organize projects and sprints.',
                        action: AppPrimaryButton(
                          onPressed: () => _openCreateWorkspace(context),
                          icon: Icons.add_rounded,
                          label: 'Create Workspace',
                        ),
                      ),
                    ),
                  ] else if (visibleWorkspaces.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: borderColor),
                      ),
                      child: AppEmptyState.noSearchResults(
                        query: _searchQuery,
                        onClearFilters: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _selectedRole = null;
                          });
                        },
                      ),
                    ),
                  ] else if (isMobile) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleWorkspaces.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) => _buildWorkspaceCard(
                        context,
                        visibleWorkspaces[index],
                        isActive: visibleWorkspaces[index].id == activeWorkspace?.id,
                      ),
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
                        itemCount: visibleWorkspaces.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1.0, color: AppColors.borderSoftFor(isDark)),
                        itemBuilder: (context, index) => _buildWorkspaceListRow(
                          context,
                          visibleWorkspaces[index],
                          isActive: visibleWorkspaces[index].id == activeWorkspace?.id,
                        ),
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
                        mainAxisExtent: 212.0,
                      ),
                      itemCount: visibleWorkspaces.length,
                      itemBuilder: (context, index) => _buildWorkspaceCard(
                        context,
                        visibleWorkspaces[index],
                        isActive: visibleWorkspaces[index].id == activeWorkspace?.id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(
    BuildContext context, {
    required bool isDark,
    required int total,
    required int ownedCount,
    required int collaboratorCount,
    required int adminCount,
    required WorkspaceModel? activeWorkspace,
  }) {
    final accentColor = AppColors.accentFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final infoColor = AppColors.infoFor(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760.0;
        final cards = [
          _WorkspaceStatTile(
            label: 'Total Workspaces',
            value: '$total',
            caption: 'Available organizations',
            dotColor: accentColor,
            isDark: isDark,
          ),
          _WorkspaceStatTile(
            label: 'Owned by You',
            value: '$ownedCount',
            caption: 'Full administrative control',
            dotColor: successColor,
            isDark: isDark,
          ),
          _WorkspaceStatTile(
            label: 'Collaborations',
            value: '$collaboratorCount',
            caption: adminCount > 0 ? '$adminCount with Admin role' : 'Member & viewer spaces',
            dotColor: infoColor,
            isDark: isDark,
          ),
          _WorkspaceStatTile(
            label: 'Active Workspace',
            value: activeWorkspace?.name ?? 'None',
            caption: activeWorkspace != null ? '@${activeWorkspace.slug}' : 'Select to continue',
            dotColor: accentColor,
            isDark: isDark,
            compactValue: true,
            onTap: activeWorkspace != null
                ? () => context.go(AppRoutes.workspaceDetailPath(activeWorkspace.id))
                : null,
          ),
        ];

        if (isWide) {
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
              SizedBox(
                width: (constraints.maxWidth - 12.0) / 2,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar({
    required bool isDark,
    required bool isMobile,
    required int visibleCount,
    required int totalCount,
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
                width: isMobile ? double.infinity : 340.0,
                child: AppTextFormField(
                  controller: _searchController,
                  hintText: 'Search workspaces by name or @slug...',
                  prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 15.0, color: textMuted),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    height: 32.0,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface2For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_WorkspaceSort>(
                        value: _sort,
                        isDense: true,
                        dropdownColor: AppColors.surfaceFor(isDark),
                        icon: Icon(Icons.unfold_more_rounded, size: 14.0, color: textMuted),
                        style: TextStyle(fontSize: 11.5, color: textPrimary),
                        items: const [
                          DropdownMenuItem(value: _WorkspaceSort.nameAsc, child: Text('Sort: Name A–Z')),
                          DropdownMenuItem(value: _WorkspaceSort.newest, child: Text('Sort: Newest')),
                          DropdownMenuItem(value: _WorkspaceSort.role, child: Text('Sort: Role')),
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
                          _ViewModeButton(
                            tooltip: 'Grid view',
                            icon: Icons.grid_view_rounded,
                            isActive: !_isListView,
                            isDark: isDark,
                            onTap: () => setState(() => _isListView = false),
                          ),
                          const SizedBox(width: 2.0),
                          _ViewModeButton(
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
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    _FilterChipPill(
                      label: 'All',
                      isActive: _selectedRole == null,
                      isDark: isDark,
                      accentColor: accentColor,
                      accentSoft: accentSoft,
                      onTap: () => setState(() => _selectedRole = null),
                    ),
                    for (final role in RoleType.values)
                      _FilterChipPill(
                        label: role.label,
                        isActive: _selectedRole == role,
                        isDark: isDark,
                        accentColor: accentColor,
                        accentSoft: accentSoft,
                        onTap: () => setState(() => _selectedRole = role),
                      ),
                  ],
                ),
              ),
              Text(
                '$visibleCount of $totalCount',
                style: AppTypography.mono(isDark, fontSize: 10.5, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard(
    BuildContext context,
    WorkspaceModel ws, {
    required bool isActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final monogramColor = _monogramColorFor(ws.slug.isNotEmpty ? ws.slug : ws.name);
    final createdLabel =
        ws.createdAt != null ? DateFormat('MMM d, y').format(ws.createdAt!.toLocal()) : null;

    Future<void> openWorkspace() async {
      await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
      if (context.mounted) {
        context.go(AppRoutes.workspaceDetailPath(ws.id));
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(18.0),
      onTap: openWorkspace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: monogramColor.withValues(alpha: isDark ? 0.25 : 0.14),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: monogramColor.withValues(alpha: 0.32)),
                ),
                alignment: Alignment.center,
                child: Text(
                  CreateWorkspaceDialog.computeInitials(ws.name),
                  style: TextStyle(
                    color: monogramColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ws.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoftFor(isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: AppColors.successFor(isDark),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        RoleBadge(role: ws.userRole, isSmall: true),
                        if (createdLabel != null) ...[
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Text(
                              createdLabel,
                              style: TextStyle(fontSize: 10.5, color: textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              AppIconButton(
                tooltip: 'Workspace Settings',
                icon: Icons.tune_rounded,
                size: 30.0,
                color: textMuted,
                onPressed: () => context.go(AppRoutes.workspaceSettingsPath(ws.id)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: Text(
              ws.description != null && ws.description!.isNotEmpty
                  ? ws.description!
                  : 'Engineering workspace · @${ws.slug}',
              style: TextStyle(fontSize: 12.0, color: textSecondary, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(height: 16.0, color: borderSoft),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surface2For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: AppColors.borderFor(isDark)),
                    ),
                    child: Text(
                      '@${ws.slug}',
                      style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              InkWell(
                onTap: () => context.go(AppRoutes.workspaceProjectCreatePath(ws.id)),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  child: Text(
                    '+ Project',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Row(
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
                  const SizedBox(width: 4.0),
                  Icon(Icons.arrow_forward_rounded, size: 13.5, color: accentColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceListRow(
    BuildContext context,
    WorkspaceModel ws, {
    required bool isActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final monogramColor = _monogramColorFor(ws.slug.isNotEmpty ? ws.slug : ws.name);

    return InkWell(
      onTap: () async {
        await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
        if (context.mounted) {
          context.go(AppRoutes.workspaceDetailPath(ws.id));
        }
      },
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
                CreateWorkspaceDialog.computeInitials(ws.name),
                style: TextStyle(
                  color: monogramColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ws.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoftFor(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successFor(isDark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    ws.description?.isNotEmpty == true ? ws.description! : '@${ws.slug}',
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.surface2For(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: AppColors.borderFor(isDark)),
              ),
              child: Text(
                '@${ws.slug}',
                style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
              ),
            ),
            const SizedBox(width: 12.0),
            RoleBadge(role: ws.userRole, isSmall: true),
            const SizedBox(width: 12.0),
            AppOutlinedButton(
              height: 30.0,
              label: 'Projects',
              onPressed: () async {
                await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
                if (context.mounted) {
                  context.go(AppRoutes.workspaceDetailPath(ws.id));
                }
              },
            ),
            const SizedBox(width: 6.0),
            AppIconButton(
              tooltip: 'Workspace Settings',
              icon: Icons.tune_rounded,
              size: 30.0,
              color: textMuted,
              onPressed: () => context.go(AppRoutes.workspaceSettingsPath(ws.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color dotColor;
  final bool isDark;
  final bool compactValue;
  final VoidCallback? onTap;

  const _WorkspaceStatTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.dotColor,
    required this.isDark,
    this.compactValue = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16.0),
      onTap: onTap,
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
              fontSize: compactValue ? 16.0 : 22.0,
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

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final Color accentColor;
  final Color accentSoft;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.accentColor,
    required this.accentSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive ? accentSoft : AppColors.surface2For(isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.35)
                : AppColors.borderFor(isDark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.0,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? accentColor : AppColors.textSecondaryFor(isDark),
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ViewModeButton({
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
