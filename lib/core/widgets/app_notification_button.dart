import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/providers/notification_provider.dart';
import '../../features/notifications/views/notification_screen.dart';
import '../providers/settings_provider.dart';

class AppNotificationButton extends StatefulWidget {
  const AppNotificationButton({super.key});

  @override
  State<AppNotificationButton> createState() => _AppNotificationButtonState();
}

class _AppNotificationButtonState extends State<AppNotificationButton> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final count = notificationProvider.unreadCount;
    final theme = Theme.of(context);

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        alignment: Alignment.topRight,
        backgroundColor: theme.colorScheme.error,
        label: Text(count > 9 ? '9+' : count.toString()),
        child: const Icon(Icons.notifications_none_rounded),
      ),
      tooltip: settings.t('notifications'),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
        if (context.mounted) {
          context.read<NotificationProvider>().fetchNotifications();
        }
      },
    );
  }
}
