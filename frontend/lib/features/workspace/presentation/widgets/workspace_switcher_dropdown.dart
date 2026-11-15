import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace Switcher Dropdown widget for Header and Navigation bars.
/// Displays active workspace, member role badge, and enables fast switching
/// between workspaces or launching the creation dialog.
class WorkspaceSwitcherDropdown extends ConsumerWidget {
  final String? activeWorkspaceId;
  final bool compact;

  const WorkspaceSwitcherDropdown({
    super.key,
    this.activeWorkspaceId,
    this.compact = false,
  });

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'W';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  void _showWorkspacePicker(BuildContext context, WidgetRef ref, List<WorkspaceModel> workspaces, WorkspaceModel? current) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 480.0, maxHeight: 520.0),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub_rounded, size: 20.0, color: AppColors.primary),
                        const SizedBox(width: 8.0),
                        Text(
                          'Switch Workspace',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20.0),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1.0),

              // Workspaces List
              Flexible(
                child: workspaces.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No workspaces found.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: workspaces.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 2.0),
                        itemBuilder: (BuildContext ctx, int index) {
                          final ws = workspaces[index];
                          final bool isSelected = current?.id == ws.id;

                          return InkWell(
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              if (!isSelected) {
                                await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
                                if (context.mounted) {
                                  context.go(AppRoutes.workspaceDetailPath(ws.id));
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  // Workspace Monogram Avatar
                                  Container(
                                    width: 36.0,
                                    height: 36.0,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _getInitials(ws.name),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),

                                  // Name and slug
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ws.name,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '@${ws.slug}',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),

                                  // Role Badge
                                  RoleBadge(role: ws.userRole, isSmall: true),

                                  // Checkmark
                                  if (isSelected) ...[
                                    const SizedBox(width: 8.0),
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 18.0,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 1.0),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18.0, color: AppColors.primary),
                        label: const Text(
                          'Create Workspace',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          CreateWorkspaceDialog.show(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.grid_view_rounded,
                          size: 18.0,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        label: Text(
                          'All Workspaces',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.go(AppRoutes.workspaces);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final workspaces = workspaceState.workspaces;
    final activeWorkspace = activeWorkspaceId != null
        ? (workspaces.where((w) => w.id == activeWorkspaceId).firstOrNull ?? workspaceState.selectedWorkspace)
        : workspaceState.selectedWorkspace;

    final displayName = activeWorkspace?.name ?? (activeWorkspaceId != null ? 'Workspace: $activeWorkspaceId' : 'Select Workspace');
    final initials = activeWorkspace != null ? _getInitials(activeWorkspace.name) : 'O';

    if (compact) {
      return Tooltip(
        message: 'Current Workspace: $displayName',
        child: InkWell(
          onTap: () => _showWorkspacePicker(context, ref, workspaces, activeWorkspace),
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            width: 36.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13.0,
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showWorkspacePicker(context, ref, workspaces, activeWorkspace),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 36.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Monogram Badge
            Container(
              width: 22.0,
              height: 22.0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4.0),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.0,
                ),
              ),
            ),
            const SizedBox(width: 8.0),

            // Workspace Name
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150.0),
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (activeWorkspace != null) ...[
              const SizedBox(width: 6.0),
              RoleBadge(role: activeWorkspace.userRole, isSmall: true),
            ],

            const SizedBox(width: 4.0),
            Icon(
              Icons.unfold_more_rounded,
              size: 16.0,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ],
        ),
      ),
    );
  }
}
