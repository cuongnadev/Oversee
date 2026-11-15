import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Reusable empty state view with illustration icon, title, description, and action button.
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
    this.iconSize = 56.0,
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
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconSize * 1.6,
                  height: iconSize * 1.6,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.0,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 20.0),
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
