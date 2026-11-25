import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/profile/domain/profile_domain.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';
import 'package:frontend/shared/widgets/app_feedback.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';
import 'package:frontend/features/profile/presentation/widgets/_streak_heatmap.dart';
import 'package:frontend/features/profile/presentation/widgets/_finished_task_item.dart';

/// Read-only profile dialog: profile info, finished-task stats, streak heatmap.
/// Opened from the header user dropdown via [ProfileDialog.show].
class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key, this.projectId});

  /// Project whose finished tasks feed the heatmap; null degrades to empty.
  final String? projectId;

  /// Shows the profile dialog, optionally loading finished tasks for [projectId].
  static Future<void> show(BuildContext context, {String? projectId}) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: context.l10n.profileTitle,
      maxWidth: 560,
      child: ProfileDialog(projectId: projectId),
    );
  }

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  Future<List<IssueModel>>? _finished;
  DateTime? _selectedDay;
  String? _themeColorOverride;

  @override
  void initState() {
    super.initState();
    _loadFinished();
  }

  Future<void> _loadFinished() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.user;
    final projectId = widget.projectId;
    if (user == null || projectId == null) return;

    final repo = ref.read(issueRepositoryProvider);
    final loaded = await repo.listProjectIssues(projectId, status: IssueStatus.done);
    if (!mounted) return;
    setState(() {
      _finished = Future.value(
        loaded.items.where((IssueModel issue) => issue.assigneeId == user.id).toList(),
      );
    });
  }

  Future<void> _resetThemeColor() async {
    setState(() => _themeColorOverride = null);
    if (mounted) {
      AppFeedback.showSuccess(context, context.l10n.profileThemeColorReset);
    }
  }

  Color _themeChipColor(UserModel user) {
    final hex = _themeColorOverride ?? user.themeColor;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse('0xFF${hex.replaceFirst('#', '')}'));
      } catch (_) {}
    }
    return AppColors.defaultSeedColor;
  }

  int _currentStreak(Map<DateTime, List<IssueModel>> groups) {
    var day = startOfDay(DateTime.now());
    var streak = 0;
    while (groups[day]?.isNotEmpty == true) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _onDayTap(DateTime day, List<IssueModel> tasks) {
    setState(() {
      _selectedDay = startOfDay(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    final header = user == null
        ? const SizedBox.shrink()
        : Row(
            children: [
              UserAvatar(
                imageUrl: user.avatarUrl,
                name: user.fullName,
                size: UserAvatarSize.xl,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.fullName,
                      style: themeTextStyle(context, isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMutedFor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

    final stats = user == null
        ? const SizedBox.shrink()
        : FutureBuilder<List<IssueModel>>(
            future: _finished,
            builder: (context, snapshot) {
              final finished = snapshot.data ?? const <IssueModel>[];
              final groups = groupFinishedIssuesByDay(finished);
              return Row(
                children: [
                  _statChip(l10n.finishedCount(finished.length), Icons.check_circle_rounded),
                  const SizedBox(width: 10),
                  _statChip('${_currentStreak(groups)} ${l10n.streakHeatmap}', Icons.local_fire_department_rounded),
                ],
              );
            },
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header is! SizedBox) ...[
          header,
          const SizedBox(height: 20),
          Divider(color: AppColors.borderSoftFor(isDark)),
          const SizedBox(height: 16),
        ],
        Text(
          l10n.profileName,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(isDark)),
        ),
        const SizedBox(height: 4),
        Text(
          user?.fullName ?? '',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimaryFor(isDark)),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.profileEmail,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(isDark)),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimaryFor(isDark)),
        ),
        const SizedBox(height: 20),
        if (user != null) ...[
          stats,
          const SizedBox(height: 20),
          // Theme color
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _themeChipColor(user),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderFor(isDark)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.profileThemeColor,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimaryFor(isDark)),
              ),
              const Spacer(),
              if (_themeColorOverride != null || user.themeColor != null)
                TextButton(
                  onPressed: _resetThemeColor,
                  child: Text(l10n.profileThemeColorReset),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Finished tasks history + streak heatmap
        Text(
          l10n.finishedTasks,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryFor(isDark)),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<IssueModel>>(
          future: _finished,
          builder: (context, snapshot) {
            final finished = snapshot.data ?? const <IssueModel>[];
            if (snapshot.connectionState == ConnectionState.waiting && finished.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (finished.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.noFinishedTasks,
                    style: TextStyle(fontSize: 13, color: AppColors.textMutedFor(isDark)),
                  ),
                ),
              );
            }
            final groups = groupFinishedIssuesByDay(finished);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreakHeatmap(
                  finishedIssues: finished,
                  selectedDay: _selectedDay,
                  onDayTap: _onDayTap,
                ),
                if (_selectedDay != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.finishedHistory,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(isDark)),
                  ),
                  const SizedBox(height: 8),
                  ...groups[_selectedDay!]!
                      .map((issue) => FinishedTaskItem(issue: issue)),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2For(Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderFor(Theme.of(context).brightness == Brightness.dark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentFor(Theme.of(context).brightness == Brightness.dark)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  TextStyle themeTextStyle(BuildContext context, {required bool isDark}) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryFor(isDark),
          ) ??
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryFor(isDark));
}
