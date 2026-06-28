import 'package:flutter/material.dart';

import '../constants/api_constants.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.radius = 22,
    this.showEditBadge = false,
    this.isLoading = false,
    this.onTap,
    this.tooltip,
  });

  final String? imageUrl;
  final String? initials;
  final double radius;
  final bool showEditBadge;
  final bool isLoading;
  final VoidCallback? onTap;
  final String? tooltip;

  static String initialsFromName(String? name, {String fallback = 'U'}) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return fallback.toUpperCase();
    return parts.map((part) => part.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedUrl = ApiConstants.resolveUploadUrl(imageUrl);
    final label = (initials?.trim().isNotEmpty ?? false)
        ? initials!.trim().toUpperCase()
        : null;
    final size = radius * 2;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: colorScheme.surface.withValues(alpha: 0.9),
          width: radius >= 40 ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl == null
          ? _AvatarFallback(label: label, radius: radius)
          : Image.network(
              resolvedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _AvatarFallback(label: label, radius: radius),
            ),
    );

    if (showEditBadge || isLoading) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.72,
              height: radius * 0.72,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: radius * 0.28,
                        height: radius * 0.28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSecondary,
                        ),
                      )
                    : Icon(
                        Icons.camera_alt_outlined,
                        size: radius * 0.28,
                        color: colorScheme.onSecondary,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onTap,
          child: avatar,
        ),
      );
    }

    return tooltip == null ? avatar : Tooltip(message: tooltip!, child: avatar);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label, required this.radius});

  final String? label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fontSize = radius < 24 ? radius * 0.62 : radius * 0.42;

    if (label == null || label!.isEmpty) {
      return Icon(Icons.person, size: radius, color: colorScheme.primary);
    }

    return Center(
      child: Text(
        label!,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
