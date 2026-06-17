import 'dart:ui';
import 'package:flutter/material.dart';

class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> screens;
  final List<NavigationItem> items;
  final VoidCallback? onSosPressed;
  final String title;
  final Widget? endDrawer;
  final List<Widget>? actions;
  final bool isSosBroadcasting;

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
  });

  int get _sosIndex => items.length ~/ 2;

  int _getEffectiveCurrentIndex() {
    if (onSosPressed != null && currentIndex >= _sosIndex) {
      return currentIndex + 1;
    }
    return currentIndex;
  }

  void _handleBottomTap(int index) {
    if (onSosPressed != null) {
      if (index == _sosIndex) {
        if (!isSosBroadcasting) onSosPressed!();
        return;
      }
      if (index > _sosIndex) {
        onIndexChanged(index - 1);
      } else {
        onIndexChanged(index);
      }
    } else {
      onIndexChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth > 800;

        return Scaffold(
          appBar: isLargeScreen ? null : AppBar(
            title: Text(title),
            elevation: 0,
            centerTitle: true,
            actions: actions,
          ),
          endDrawer: endDrawer,
          body: isLargeScreen ? _buildLargeScreen(context) : _buildSmallScreen(context),
          extendBody: false,
          bottomNavigationBar: isLargeScreen ? null : _buildGlassBottomBar(context),
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
                    Icon(Icons.local_police, color: colorScheme.primary, size: 28),
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
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = currentIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onIndexChanged(index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                                    : colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(alpha: 0.7),
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
                    if (onSosPressed != null) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isSosBroadcasting ? null : onSosPressed,
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSosBroadcasting
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isSosBroadcasting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.emergency, color: Colors.white, size: 18),
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
                    ...?actions,
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
              child: screens[currentIndex],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  //  MOBILE: Same as before
  // ─────────────────────────────────
  Widget _buildSmallScreen(BuildContext context) {
    return screens[currentIndex];
  }

  Widget _buildGlassBottomBar(BuildContext context) {
    List<BottomNavigationBarItem> barItems = [];
    int itemIndex = 0;
    
    int totalItems = onSosPressed != null ? items.length + 1 : items.length;

    for (int i = 0; i < totalItems; i++) {
      if (onSosPressed != null && i == _sosIndex) {
        barItems.add(BottomNavigationBarItem(
          icon: isSosBroadcasting 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
            : const Icon(Icons.emergency, color: Colors.redAccent, size: 28),
          label: 'SOS',
        ));
      } else {
        barItems.add(BottomNavigationBarItem(
          icon: Icon(items[itemIndex].icon),
          activeIcon: items[itemIndex].selectedIcon != null ? Icon(items[itemIndex].selectedIcon) : null,
          label: items[itemIndex].label,
        ));
        itemIndex++;
      }
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            currentIndex: _getEffectiveCurrentIndex(),
            onTap: _handleBottomTap,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            selectedFontSize: 12,
            unselectedFontSize: 11,
            items: barItems,
          ),
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
