import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

enum UserAvatarSize {
  xs(20.0, 9.0),
  sm(28.0, 11.0),
  md(36.0, 13.0),
  lg(48.0, 16.0),
  xl(64.0, 22.0);

  final double dimension;
  final double fontSize;

  const UserAvatarSize(this.dimension, this.fontSize);
}

/// Circular User Avatar displaying profile image or deterministic initial letters.
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

  /// Generates a deterministic pastel color from user name.
  static Color generateColorFromName(String? name) {
    if (name == null || name.isEmpty) return AppColors.primary;
    final List<Color> palette = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF0EA5E9), // Sky
      const Color(0xFF10B981), // Emerald
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
      const Color(0xFF6366F1), // Indigo 500
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return palette[hash.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
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
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
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
      final double statusSize = dimension * 0.28;
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: statusSize,
              height: statusSize,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.textMutedLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Overlapping avatar cluster for teams and multi-assignee lists.
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
    this.overlapOffset = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();

    final int visibleCount = names.length > maxVisible ? maxVisible : names.length;
    final int extraCount = names.length - visibleCount;
    final double dimension = size.dimension;

    return SizedBox(
      height: dimension,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < visibleCount; i++) ...[
            Align(
              widthFactor: (dimension - overlapOffset) / dimension,
              child: UserAvatar(
                name: names[i],
                imageUrl: (imageUrls != null && i < imageUrls!.length) ? imageUrls![i] : null,
                size: size,
              ),
            ),
          ],
          if (extraCount > 0) ...[
            Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                color: const Color(0xFF64748B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.fontSize * 0.9,
                    fontWeight: FontWeight.w700,
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
