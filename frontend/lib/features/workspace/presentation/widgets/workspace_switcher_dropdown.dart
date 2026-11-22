import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace Switcher Dropdown widget for Header and Navigation bars aligned with Figma .project-button.
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

  void _showWorkspacePicker(
    BuildContext context,
    WidgetRef ref,
    List<WorkspaceModel> workspaces,
    WorkspaceModel? current,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final filtered = searchQuery.trim().isEmpty
                ? workspaces
                : workspaces
                    .where((w) =>
                        w.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        w.slug.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              constraints: const BoxConstraints(maxWidth: 460.0, maxHeight: 520.0),
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusXl),
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                    blurRadius: 24.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers_rounded, size: 18.0, color: accentColor),
                            const SizedBox(width: 8.0),
                            Text(
                              'Switch Workspace',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18.0, color: textMuted),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          tooltip: 'Close',
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1.0, color: borderColor),

                  if (workspaces.length > 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 4.0),
                      child: AppTextFormField(
                        hintText: 'Search workspaces...',
                        prefixIcon: Icon(Icons.search_rounded, size: 16.0, color: textMuted),
                        onChanged: (val) => setSheetState(() => searchQuery = val),
                      ),
                    ),

                  // Workspaces List
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No workspaces found.',
                                style: TextStyle(fontSize: 12.5, color: textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 2.0),
                            itemBuilder: (BuildContext itemCtx, int index) {
                              final ws = filtered[index];
                              final bool isSelected = current?.id == ws.id;

                              return InkWell(
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                hoverColor: AppColors.hoverFor(isDark),
                                onTap: () async {
                                  Navigator.of(sheetContext).pop();
                                  if (!isSelected) {
                                    await ref
                                        .read(workspaceNotifierProvider.notifier)
                                        .selectWorkspace(ws.id);
                                    if (context.mounted) {
                                      context.go(AppRoutes.workspaceDetailPath(ws.id));
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
                                  decoration: BoxDecoration(
                                    color: isSelected ? accentSoft : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32.0,
                                        height: 32.0,
                                        decoration: BoxDecoration(
                                          color: isSelected ? accentColor : accentSoft,
                                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                          border: Border.all(
                                            color: accentColor.withValues(alpha: 0.22),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          CreateWorkspaceDialog.computeInitials(ws.name),
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : accentColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ws.name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '@${ws.slug}',
                                              style: AppTypography.mono(
                                                isDark,
                                                fontSize: 10.5,
                                                color: textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      RoleBadge(role: ws.userRole, isSmall: true),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8.0),
                                        Icon(Icons.check_rounded, size: 16.0, color: accentColor),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  Divider(height: 1.0, color: borderColor),

                  // Bottom Actions
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: Icon(Icons.add_rounded, size: 16.0, color: accentColor),
                            label: Text(
                              'Create Workspace',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
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
                            icon: Icon(Icons.grid_view_rounded, size: 15.0, color: textSecondary),
                            label: Text(
                              'All Workspaces',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
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
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final workspaces = workspaceState.workspaces;
    final activeWorkspace = activeWorkspaceId != null
        ? (workspaces.where((w) => w.id == activeWorkspaceId).firstOrNull ??
            workspaceState.selectedWorkspace)
        : workspaceState.selectedWorkspace;

    final displayName = activeWorkspace?.name ??
        (activeWorkspaceId != null ? 'Workspace: $activeWorkspaceId' : 'Select Workspace');
    final initials = activeWorkspace != null
        ? CreateWorkspaceDialog.computeInitials(activeWorkspace.name)
        : 'O';

    if (compact) {
      return Tooltip(
        message: 'Current Workspace: $displayName',
        child: InkWell(
          onTap: () => _showWorkspacePicker(context, ref, workspaces, activeWorkspace),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            width: 34.0,
            height: 34.0,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: accentColor.withValues(alpha: 0.22), width: 1.0),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 12.0,
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showWorkspacePicker(context, ref, workspaces, activeWorkspace),
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      hoverColor: AppColors.hoverFor(isDark),
      child: Container(
        height: 34.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Figma .project-icon small square badge
            Container(
              width: 21.0,
              height: 21.0,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150.0),
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
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
            Icon(Icons.unfold_more_rounded, size: 15.0, color: textMuted),
          ],
        ),
      ),
    );
  }
}
