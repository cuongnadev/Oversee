import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

enum UserAvatarSize {
  xs(22.0, 8.5),
  sm(28.0, 10.5),
  md(36.0, 12.0),
  lg(44.0, 14.0),
  xl(64.0, 21.0);

  final double dimension;
  final double fontSize;

  const UserAvatarSize(this.dimension, this.fontSize);
}

/// Circular User Avatar aligned with Figma curated avatar palette.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final UserAvatarSize size;
  final double? customSize;
  final bool showStatus;
  final bool isOnline;
  final VoidCallback? onTap;
  final bool showTooltip;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = UserAvatarSize.md,
    this.customSize,
    this.showStatus = false,
    this.isOnline = false,
    this.onTap,
    this.showTooltip = true,
  });

  /// Extracts up to 2 uppercase initials from full name.
  static String extractInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final String first = parts[0];
      return first.length >= 2 ? first.substring(0, 2).toUpperCase() : first.toUpperCase();
    }
    final String first = parts.first;
    final String last = parts.last;
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
  }

  /// Generates a deterministic muted tone from the Figma avatar palette.
  static Color generateColorFromName(String? name) {
    if (name == null || name.isEmpty) return AppColors.avatarPalette.first;
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return AppColors.avatarPalette[hash.abs() % AppColors.avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double dimension = customSize ?? size.dimension;
    final double fontSize = customSize != null ? customSize! * 0.38 : size.fontSize;
    final Color bgColor = generateColorFromName(name);
    final String initials = extractInitials(name);

    Widget avatarWidget = Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0x18FFFFFF) : AppColors.surfaceLight,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: dimension,
              height: dimension,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildInitials(initials, fontSize),
            )
          : _buildInitials(initials, fontSize),
    );

    if (showStatus) {
      final double statusSize = (dimension * 0.29).clamp(7.0, 11.0);
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: statusSize,
              height: statusSize,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.successFor(isDark) : AppColors.textMutedFor(isDark),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.sidebarFor(isDark),
                  width: 1.8,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatarWidget = InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatarWidget,
      );
    }

    if (showTooltip && name != null && name!.isNotEmpty) {
      avatarWidget = Tooltip(
        message: name!,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildInitials(String initials, double fontSize) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Overlapping avatar cluster aligned with Figma .avatar-group.
class UserAvatarGroup extends StatelessWidget {
  final List<String> names;
  final List<String?>? imageUrls;
  final UserAvatarSize size;
  final int maxVisible;
  final double overlapOffset;

  const UserAvatarGroup({
    super.key,
    required this.names,
    this.imageUrls,
    this.size = UserAvatarSize.sm,
    this.maxVisible = 3,
    this.overlapOffset = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int visibleCount = names.length > maxVisible ? maxVisible : names.length;
    final int extraCount = names.length - visibleCount;
    final double dimension = size.dimension;
    final double widthFactor = ((dimension - overlapOffset) / dimension).clamp(0.4, 1.0);

    return SizedBox(
      height: dimension,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < visibleCount; i++) ...[
            Align(
              widthFactor: widthFactor,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgFor(isDark), width: 1.8),
                ),
                child: UserAvatar(
                  name: names[i],
                  imageUrl: (imageUrls != null && i < imageUrls!.length) ? imageUrls![i] : null,
                  size: size,
                ),
              ),
            ),
          ],
          if (extraCount > 0) ...[
            Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                color: AppColors.surface3For(isDark),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.bgFor(isDark),
                  width: 1.8,
                ),
              ),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(isDark),
                    fontSize: size.fontSize * 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
