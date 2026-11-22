import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Reusable empty state view aligned with Figma .empty-state styling.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final double iconSize;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.action,
    this.iconSize = 36.0,
  });

  /// Factory for empty projects list in a workspace.
  factory AppEmptyState.noProjects({VoidCallback? onCreateProject}) {
    return AppEmptyState(
      icon: Icons.assignment_outlined,
      title: 'No Projects Found',
      description:
          'This workspace doesn\'t have any projects yet. Create your first project to start organizing tasks, backlogs, and sprints.',
      action: onCreateProject != null
          ? AppPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Create First Project',
              onPressed: onCreateProject,
            )
          : null,
    );
  }

  /// Factory for empty product backlog.
  factory AppEmptyState.noBacklog({VoidCallback? onCreateIssue}) {
    return AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Your Product Backlog is Empty',
      description:
          'Create tasks, bugs, or user stories to plan upcoming sprints.',
      action: onCreateIssue != null
          ? AppPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Create First Issue',
              onPressed: onCreateIssue,
            )
          : null,
    );
  }

  /// Factory for empty sprints in a project.
  factory AppEmptyState.noSprints({VoidCallback? onGoToPlanning}) {
    return AppEmptyState(
      icon: Icons.timer_off_outlined,
      title: 'No Sprints Available',
      description:
          'This project currently has no sprints created. Plan and start a sprint to begin tracking team velocity and burndown progress.',
      action: onGoToPlanning != null
          ? AppPrimaryButton(
              icon: Icons.timer_outlined,
              label: 'Go to Sprint Planning',
              onPressed: onGoToPlanning,
            )
          : null,
    );
  }

  /// Factory for no active sprint in Kanban board.
  factory AppEmptyState.noActiveSprint({VoidCallback? onGoToPlanning}) {
    return AppEmptyState(
      icon: Icons.play_disabled_rounded,
      title: 'No Active Sprint',
      description:
          'There is no active sprint running on this board. Start a planned sprint from Sprint Planning to display tasks.',
      action: onGoToPlanning != null
          ? AppPrimaryButton(
              icon: Icons.play_arrow_rounded,
              label: 'Go to Sprint Planning',
              onPressed: onGoToPlanning,
            )
          : null,
    );
  }

  /// Factory for no matching search / filter results.
  factory AppEmptyState.noSearchResults({String? query, VoidCallback? onClearFilters}) {
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Matching Results',
      description: query != null && query.isNotEmpty
          ? 'No items matched "$query". Try adjusting your search keywords or clearing active filters.'
          : 'No items match your active filters. Try adjusting filter selections.',
      action: onClearFilters != null
          ? AppOutlinedButton(
              icon: Icons.filter_alt_off_rounded,
              label: 'Clear Filters',
              onPressed: onClearFilters,
            )
          : null,
    );
  }

  /// Factory for empty team members.
  factory AppEmptyState.noMembers({VoidCallback? onInviteMember}) {
    return AppEmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No Team Members',
      description:
          'There are no members assigned to this workspace yet. Invite teammates to collaborate.',
      action: onInviteMember != null
          ? AppPrimaryButton(
              icon: Icons.person_add_rounded,
              label: 'Invite Member',
              onPressed: onInviteMember,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface2For(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusXl),
                    border: Border.all(
                      color: AppColors.borderFor(isDark),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: AppColors.textMutedFor(isDark),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(isDark),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 6.0),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryFor(isDark),
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 18.0),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
