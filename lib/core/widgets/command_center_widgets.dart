import 'package:flutter/material.dart';

class CommandColors {
  static const navy = Color(0xFF0F3D87);
  static const navyDark = Color(0xFF082A5E);
  static const navySoft = Color(0xFF1E5AB6);
  static const night = Color(0xFF071A3B);
  static const accentYellow = Color(0xFFFFD100);
  static const softBackground = Color(0xFFF3F6FA);
  static const success = Color(0xFF168A4A);
  static const warning = Color(0xFFE79819);
  static const danger = Color(0xFFE5484D);
}

class CommandHeaderBadge {
  final IconData icon;
  final String label;
  final Color? color;

  const CommandHeaderBadge({
    required this.icon,
    required this.label,
    this.color,
  });
}

class CommandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<CommandHeaderBadge> badges;
  final Widget? trailing;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  const CommandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badges = const [],
    this.trailing,
    this.accentColor,
    this.padding,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.secondary;

    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            CommandColors.navyDark,
            CommandColors.navy,
            CommandColors.navySoft,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        boxShadow: [
          BoxShadow(
            color: CommandColors.navy.withValues(alpha: 0.22),
            blurRadius: compact ? 14 : 20,
            offset: Offset(0, compact ? 6 : 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 48,
                height: compact ? 36 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(compact ? 13 : 16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(icon, color: accent, size: compact ? 20 : 25),
              ),
              SizedBox(width: compact ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 18 : 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      subtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: compact ? 11.5 : 13,
                        height: compact ? 1.22 : 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          if (badges.isNotEmpty) ...[
            SizedBox(height: compact ? 10 : 16),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: badges.map((badge) {
                final badgeColor = badge.color ?? Colors.white;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badge.icon, color: badgeColor, size: 15),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 150 : 190,
                        ),
                        child: Text(
                          badge.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: compact ? 10.5 : 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class CommandMetricData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const CommandMetricData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });
}

class CommandMetricGrid extends StatelessWidget {
  final List<CommandMetricData> metrics;
  final int mobileColumns;
  final bool compact;

  const CommandMetricGrid({
    super.key,
    required this.metrics,
    this.mobileColumns = 2,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : (width >= 600 ? 3 : mobileColumns);
        const spacing = 10.0;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: CommandMetricCard(metric: metric, compact: compact),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class CommandMetricCard extends StatelessWidget {
  final CommandMetricData metric;
  final bool compact;

  const CommandMetricCard({
    super.key,
    required this.metric,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 78 : 112),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommandIconBox(
                icon: metric.icon,
                color: metric.color,
                size: compact ? 30 : 38,
                iconSize: compact ? 17 : 20,
              ),
              const Spacer(),
              Icon(
                Icons.north_east_rounded,
                color: metric.color.withValues(alpha: 0.38),
                size: 17,
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: TextStyle(
                color: theme.textTheme.titleLarge?.color,
                fontSize: compact ? 19 : 25,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 1 : 2),
          Text(
            metric.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class CommandQuickActionTile extends StatelessWidget {
  final String label;
  final String? caption;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool destructive;

  const CommandQuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    this.caption,
    this.onTap,
    this.color,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final tileColor = destructive
        ? CommandColors.danger
        : (color ?? theme.colorScheme.primary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: commandCardDecoration(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 86),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CommandIconBox(
                  icon: icon,
                  color: enabled ? tileColor : theme.disabledColor,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? theme.textTheme.bodyLarge?.color
                        : theme.disabledColor,
                    fontSize: 13,
                    height: 1.16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.58,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CommandSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommandSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          CommandIconBox(
            icon: icon!,
            color: theme.colorScheme.primary,
            size: 34,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class CommandBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommandBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CommandIconBox(icon: icon, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.68,
                    ),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.55)),
                minimumSize: const Size(48, 42),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class CommandStatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  const CommandStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: filled ? color : color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 14),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommandEmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommandEmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: commandCardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommandIconBox(
            icon: icon,
            color: theme.colorScheme.primary,
            size: 54,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class CommandSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const CommandSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        hintStyle: TextStyle(
          color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.48),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.16),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class CommandIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const CommandIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

BoxDecoration commandCardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
        ),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
