import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class ResponsiveShell extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> screens;
  final List<NavigationItem> items;
  final VoidCallback? onSosPressed;
  final String title;
  final Widget? endDrawer;
  final List<Widget>? actions;
  final bool isSosBroadcasting;
  final bool showAppBar;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.screens,
    required this.items,
    this.onSosPressed,
    required this.title,
    this.endDrawer,
    this.actions,
    this.isSosBroadcasting = false,
    this.showAppBar = true,
  });

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  bool _isFabMenuOpen = false;

  _BottomBarConfig _getBottomBarConfig() {
    if (widget.items.length == 4 && widget.onSosPressed != null) {
      return _BottomBarConfig(
        leftItemIndices: [0, 3],
        rightItemIndices: [2],
        fabItemIndices: [1],
        hasSos: true,
      );
    } else if (widget.items.length == 5 && widget.onSosPressed != null) {
      return _BottomBarConfig(
        leftItemIndices: [0, 4],
        rightItemIndices: [2],
        fabItemIndices: [1, 3],
        hasSos: true,
      );
    } else if (widget.onSosPressed == null && widget.items.length >= 5) {
      final lastIndex = widget.items.length - 1;
      final visibleIndices = <int>{0, 1, lastIndex - 1, lastIndex};
      final fabIndices = List<int>.generate(
        widget.items.length,
        (index) => index,
      ).where((index) => !visibleIndices.contains(index)).toList();
      return _BottomBarConfig(
        leftItemIndices: [0, 1],
        rightItemIndices: [lastIndex - 1, lastIndex],
        fabItemIndices: fabIndices,
        hasSos: false,
      );
    } else {
      // Fallback
      return _BottomBarConfig(
        leftItemIndices: [0, 1],
        rightItemIndices: [2, 3],
        fabItemIndices: [],
        hasSos: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth > 800;

        return Scaffold(
          appBar: (isLargeScreen || !widget.showAppBar)
              ? null
              : AppBar(
                  title: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18),
                  ),
                  elevation: 0,
                  centerTitle: true,
                  actions: widget.actions,
                ),
          endDrawer: widget.endDrawer,
          body: isLargeScreen
              ? _buildLargeScreen(context)
              : _buildSmallScreen(context),
          extendBody: false,
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  WEB: Horizontal top navigation bar + content
  // ─────────────────────────────────────────────
  Widget _buildLargeScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ── Horizontal Navigation Bar ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left side: App Logo / Name
              Positioned(
                left: 24,
                child: Row(
                  children: [
                    Icon(
                      Icons.local_police,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SRS App',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Center: Navigation items
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final isSelected = widget.currentIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isFabMenuOpen = false;
                          });
                          widget.onIndexChanged(index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Right side: SOS Button and Actions
              Positioned(
                right: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onSosPressed != null) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.isSosBroadcasting
                              ? null
                              : widget.onSosPressed,
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isSosBroadcasting
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                widget.isSosBroadcasting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.emergency,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                const SizedBox(width: 8),
                                const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    ...?widget.actions,
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Content Area ──
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: widget.screens[widget.currentIndex],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  //  MOBILE: Floating Stack UI
  // ─────────────────────────────────
  Widget _buildSmallScreen(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final config = _getBottomBarConfig();
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Screen Content (shifted up slightly to clear custom bottom bar height)
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(bottom: 75 + bottomPadding),
            child: widget.screens[widget.currentIndex],
          ),
        ),

        // Floating Card Menu (rendered directly above bottom bar)
        if (_isFabMenuOpen && config.fabItemIndices.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 85 + bottomPadding,
            child: Card(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: theme.cardColor.withValues(alpha: 0.95),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 16.0,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: config.fabItemIndices.map((index) {
                        final item = widget.items[index];
                        final isSelected = widget.currentIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _isFabMenuOpen = false;
                            });
                            widget.onIndexChanged(index);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.7),
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.primaryColor
                                        : theme.textTheme.bodyMedium?.color
                                              ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Custom Bottom Navigation Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildCustomBottomBar(context, config, settings, theme),
        ),
      ],
    );
  }

  Widget _buildCustomBottomBar(
    BuildContext context,
    _BottomBarConfig config,
    SettingsProvider settings,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 75 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side item 1
              _buildBottomBarItem(config.leftItemIndices[0], theme),

              // Left side item 2
              _buildBottomBarItem(config.leftItemIndices[1], theme),

              // Middle: FAB Toggle
              _buildMiddleFab(theme, config),

              // Right side item 1: SOS or Peralatan
              config.hasSos
                  ? _buildSosItem(theme)
                  : _buildBottomBarItem(config.rightItemIndices[0], theme),

              // Right side item 2: Incident or Ahli
              config.hasSos
                  ? _buildBottomBarItem(config.rightItemIndices[0], theme)
                  : _buildBottomBarItem(config.rightItemIndices[1], theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem(int index, ThemeData theme) {
    final item = widget.items[index];
    final isSelected = widget.currentIndex == index && !_isFabMenuOpen;
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isFabMenuOpen = false;
            });
            widget.onIndexChanged(index);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected && item.selectedIcon != null
                    ? item.selectedIcon
                    : item.icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSosItem(ThemeData theme) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isFabMenuOpen = false;
            });
            if (widget.onSosPressed != null && !widget.isSosBroadcasting) {
              widget.onSosPressed!();
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.isSosBroadcasting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.emergency,
                      color: Colors.redAccent,
                      size: 26,
                    ),
              const SizedBox(height: 4),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleFab(ThemeData theme, _BottomBarConfig config) {
    final colorScheme = theme.colorScheme;
    final isFabItemSelected = config.fabItemIndices.contains(
      widget.currentIndex,
    );
    final isCurrentFabActive = _isFabMenuOpen || isFabItemSelected;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isCurrentFabActive
                      ? [
                          colorScheme.secondary,
                          colorScheme.secondary.withValues(alpha: 0.8),
                        ]
                      : [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.8),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isCurrentFabActive
                                ? colorScheme.secondary
                                : colorScheme.primary)
                            .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isFabMenuOpen ? 0.125 : 0.0,
                child: Icon(
                  _isFabMenuOpen ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  const NavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
}

class _BottomBarConfig {
  final List<int> leftItemIndices;
  final List<int> rightItemIndices;
  final List<int> fabItemIndices;
  final bool hasSos;

  _BottomBarConfig({
    required this.leftItemIndices,
    required this.rightItemIndices,
    required this.fabItemIndices,
    required this.hasSos,
  });
}
