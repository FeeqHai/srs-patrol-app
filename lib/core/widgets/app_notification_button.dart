import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Shared entry point for operational notices in the app bar.
///
/// The notification feed is intentionally empty until server-side operational
/// events (such as a squad transfer) are connected to it.
class AppNotificationButton extends StatelessWidget {
  const AppNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return IconButton(
      icon: const Icon(Icons.notifications_none_rounded),
      tooltip: settings.t('Notifikasi'),
      onPressed: () => _showNotificationSheet(context),
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final settings = sheetContext.watch<SettingsProvider>();
        final theme = Theme.of(sheetContext);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    settings.t('Notifikasi'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Icon(
                  Icons.notifications_off_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.t('Tiada notifikasi baharu'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
