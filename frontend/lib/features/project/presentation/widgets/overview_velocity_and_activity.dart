import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Sprint Velocity grouped bar chart card aligned with Figma Overview row 2 left.
class OverviewVelocityCard extends StatelessWidget {
  final ProjectOverviewState state;
  final bool isDark;

  const OverviewVelocityCard({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final plannedBarColor = AppColors.surface3For(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final chartGrid = AppColors.chartGridFor(isDark);

    final recentSprints = state.sprints.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sprint Velocity',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recentSprints.isEmpty
                        ? 'Story points across recent sprints'
                        : 'Story points · ${recentSprints.length} recent sprint${recentSprints.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(plannedBarColor, 'Planned', textMuted, hasBorder: true, borderColor: borderColor),
                  const SizedBox(width: 10),
                  _legendDot(accentColor, 'Completed', textMuted),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSprints.isEmpty)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  'Velocity trends will appear once sprints are planned.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 175,
              child: RepaintBoundary(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _computeMaxY(recentSprints),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: chartGrid,
                        strokeWidth: 1,
                        dashArray: [3, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (val, _) => Text(
                            '${val.toInt()}',
                            style: AppTypography.mono(isDark, fontSize: 9.5, color: textMuted),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= recentSprints.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                recentSprints[idx].name,
                                style: TextStyle(fontSize: 10, color: textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(recentSprints.length, (i) {
                      final sprint = recentSprints[i];
                      final isSelected = sprint.id == state.activeSprint?.id;
                      final planned = sprint.capacity ?? (isSelected ? state.totalStoryPoints : 0.0);
                      final completed = isSelected ? state.completedStoryPoints : 0.0;
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: planned,
                            color: plannedBarColor,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                          BarChartRodData(
                            toY: completed,
                            color: accentColor,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _computeMaxY(List<dynamic> recentSprints) {
    double maxVal = state.totalStoryPoints;
    for (final s in state.sprints.take(4)) {
      if ((s.capacity ?? 0) > maxVal) maxVal = s.capacity!;
    }
    return maxVal <= 0 ? 20.0 : (maxVal * 1.2).ceilToDouble();
  }

  Widget _legendDot(
    Color color,
    String label,
    Color textColor, {
    bool hasBorder = false,
    Color? borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: hasBorder && borderColor != null ? Border.all(color: borderColor) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, color: textColor)),
      ],
    );
  }
}

/// Recent Activity feed card aligned with Figma Overview row 2 right (node 1:892).
class OverviewRecentActivityCard extends StatelessWidget {
  final ProjectOverviewState state;
  final String workspaceId;
  final String projectId;
  final bool isDark;

  const OverviewRecentActivityCard({
    super.key,
    required this.state,
    required this.workspaceId,
    required this.projectId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final projectKey = state.project?.key ?? 'OVS';

    final recentIssues = List<IssueModel>.from(state.sprintIssues)
      ..sort((a, b) {
        final da = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final db = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return db.compareTo(da);
      });
    final visible = recentIssues.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.projectBoardPath(workspaceId, projectId)),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View all', style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  'Recent issue updates and sprint activity will appear here.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: List.generate(visible.length, (index) {
                final issue = visible[index];
                final isLast = index == visible.length - 1;
                final actorName = issue.assignee?.fullName.isNotEmpty == true
                    ? issue.assignee!.fullName
                    : (issue.assignee?.email ?? 'Team Member');

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          UserAvatar(
                            name: actorName,
                            size: UserAvatarSize.xs,
                            showTooltip: false,
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: borderColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 2 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35),
                                  children: [
                                    TextSpan(
                                      text: actorName,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                    TextSpan(text: ' updated "${issue.title}" to ${issue.status.label}'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    issue.formattedKey(projectKey),
                                    style: AppTypography.mono(
                                      isDark,
                                      fontSize: 10,
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatRelativeTime(issue.updatedAt ?? issue.createdAt),
                                    style: TextStyle(fontSize: 10, color: textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
