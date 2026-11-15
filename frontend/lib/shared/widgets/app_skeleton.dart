import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Base customizable shimmer block for loading skeletons across Oversee.
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? baseColor;
  final Color? highlightColor;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.baseColor,
    this.highlightColor,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
    this.baseColor,
    this.highlightColor,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  const AppSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 100.0,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  }) : shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedBaseColor = baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final resolvedHighlightColor = highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));

    return Shimmer.fromColors(
      baseColor: resolvedBaseColor,
      highlightColor: resolvedHighlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: resolvedBaseColor,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? (borderRadius ?? BorderRadius.circular(6.0))
              : null,
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for the Dashboard Screen.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar Skeleton
          const Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSkeleton.circle(size: 24),
                  SizedBox(width: 10),
                  AppSkeleton(width: 100, height: 20),
                  SizedBox(width: 8),
                  AppSkeleton(width: 120, height: 32),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSkeleton(width: 100, height: 36),
                  SizedBox(width: 10),
                  AppSkeleton.circle(size: 36),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4 KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1000;
              final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

              if (isWide) {
                return Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index < 3 ? 16.0 : 0.0),
                        child: _buildMetricCardSkeleton(isDark),
                      ),
                    );
                  }),
                );
              }

              if (isTablet) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(4, (_) {
                    return SizedBox(
                      width: (constraints.maxWidth - 16) / 2,
                      child: _buildMetricCardSkeleton(isDark),
                    );
                  }),
                );
              }

              // Mobile (< 600px): Stack 1 card per row
              return Column(
                children: List.generate(4, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < 3 ? 12.0 : 0.0),
                    child: _buildMetricCardSkeleton(isDark),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 24),

          // Burndown Chart Card Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    AppSkeleton(width: 160, height: 20),
                    AppSkeleton(width: 140, height: 16),
                  ],
                ),
                SizedBox(height: 24),
                AppSkeleton(width: double.infinity, height: 240),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two Column Charts Skeleton
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildChartBoxSkeleton(isDark, height: 250)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildChartBoxSkeleton(isDark, height: 250)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildChartBoxSkeleton(isDark, height: 220)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildChartBoxSkeleton(isDark, height: 220)),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildChartBoxSkeleton(isDark, height: 250),
                  const SizedBox(height: 20),
                  _buildChartBoxSkeleton(isDark, height: 250),
                  const SizedBox(height: 20),
                  _buildChartBoxSkeleton(isDark, height: 220),
                  const SizedBox(height: 20),
                  _buildChartBoxSkeleton(isDark, height: 220),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildMetricCardSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 100, height: 14),
              AppSkeleton.circle(size: 28),
            ],
          ),
          SizedBox(height: 14),
          AppSkeleton(width: 80, height: 24),
          SizedBox(height: 12),
          AppSkeleton(width: double.infinity, height: 6),
          SizedBox(height: 8),
          AppSkeleton(width: 120, height: 12),
        ],
      ),
    );
  }

  static Widget _buildChartBoxSkeleton(bool isDark, {required double height}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppSkeleton.circle(size: 22),
              SizedBox(width: 10),
              AppSkeleton(width: 140, height: 16),
            ],
          ),
          const SizedBox(height: 20),
          AppSkeleton(width: double.infinity, height: height - 60),
        ],
      ),
    );
  }
}

/// Shimmer loading skeleton for the Kanban Board Screen.
class KanbanBoardSkeleton extends StatelessWidget {
  const KanbanBoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sprint Header Bar Skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppSkeleton(width: 140, height: 20),
                    SizedBox(width: 12),
                    AppSkeleton(width: 80, height: 18),
                  ],
                ),
                AppSkeleton(width: 160, height: 16),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter Toolbar Skeleton
          const Row(
            children: [
              Expanded(child: AppSkeleton(height: 38)),
              SizedBox(width: 12),
              AppSkeleton(width: 100, height: 38),
              SizedBox(width: 12),
              AppSkeleton(width: 100, height: 38),
            ],
          ),
          const SizedBox(height: 16),

          // Kanban Columns Skeleton
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return Container(
                      width: 290,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  AppSkeleton.circle(size: 10),
                                  SizedBox(width: 8),
                                  AppSkeleton(width: 90, height: 16),
                                ],
                              ),
                              AppSkeleton(width: 28, height: 18),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              itemCount: 3,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildCardSkeleton(isDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCardSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 60, height: 14),
              AppSkeleton.circle(size: 16),
            ],
          ),
          SizedBox(height: 10),
          AppSkeleton(width: double.infinity, height: 14),
          SizedBox(height: 6),
          AppSkeleton(width: 140, height: 12),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 50, height: 16),
              AppSkeleton.circle(size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading skeleton for the Product Backlog Screen.
class BacklogSkeleton extends StatelessWidget {
  final int rowCount;

  const BacklogSkeleton({super.key, this.rowCount = 6});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header toolbar skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 160, height: 24),
              AppSkeleton(width: 120, height: 16),
            ],
          ),
          const SizedBox(height: 14),

          // Filter bar skeleton
          const Row(
            children: [
              Expanded(child: AppSkeleton(height: 38)),
              SizedBox(width: 10),
              AppSkeleton(width: 80, height: 38),
              SizedBox(width: 10),
              AppSkeleton(width: 80, height: 38),
            ],
          ),
          const SizedBox(height: 14),

          // Quick create input skeleton
          const AppSkeleton(width: double.infinity, height: 44),
          const SizedBox(height: 16),

          // Backlog rows skeleton
          Expanded(
            child: ListView.separated(
              itemCount: rowCount,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: const Row(
                    children: [
                      AppSkeleton(width: 18, height: 18),
                      SizedBox(width: 12),
                      AppSkeleton(width: 60, height: 16),
                      SizedBox(width: 14),
                      Expanded(child: AppSkeleton(height: 14)),
                      SizedBox(width: 16),
                      AppSkeleton(width: 60, height: 18),
                      SizedBox(width: 12),
                      AppSkeleton(width: 40, height: 18),
                      SizedBox(width: 12),
                      AppSkeleton.circle(size: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading skeleton for the Project List Screen.
class ProjectGridSkeleton extends StatelessWidget {
  final int count;

  const ProjectGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 180,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppSkeleton.circle(size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeleton(width: 120, height: 16),
                            SizedBox(height: 6),
                            AppSkeleton(width: 60, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  AppSkeleton(width: double.infinity, height: 12),
                  SizedBox(height: 8),
                  AppSkeleton(width: 180, height: 12),
                  Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeleton(width: 80, height: 14),
                      AppSkeleton(width: 60, height: 14),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Shimmer loading skeleton for Workspace Settings Member List.
class MemberListSkeleton extends StatelessWidget {
  final int count;

  const MemberListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      ),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AppSkeleton.circle(size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 140, height: 15),
                    SizedBox(height: 6),
                    AppSkeleton(width: 200, height: 12),
                  ],
                ),
              ),
              AppSkeleton(width: 90, height: 32),
              SizedBox(width: 12),
              AppSkeleton.circle(size: 28),
            ],
          ),
        );
      },
    );
  }
}
